import os
import sys
import json
import datetime
import firebase_admin
from firebase_admin import credentials, firestore, auth, storage

def deserialize_value(val):
    """Mengembalikan format JSON-compatible ke tipe data khusus Firestore (GeoPoint, Timestamp)."""
    if isinstance(val, dict):
        if val.get("_type") == "GeoPoint":
            return firestore.GeoPoint(val["latitude"], val["longitude"])
        elif val.get("_type") == "Timestamp":
            return datetime.datetime.fromtimestamp(val["seconds"], tz=datetime.timezone.utc)
        elif val.get("_type") == "DateTime":
            return datetime.datetime.fromisoformat(val["iso"])
        else:
            return {k: deserialize_value(v) for k, v in val.items()}
    elif isinstance(val, list):
        return [deserialize_value(x) for x in val]
    else:
        return val

def main():
    print("=== Memulai Restorasi Data Firebase (Firestore & Storage) ===")
    
    cred_path = "serviceAccountKey.json"
    bucket_name = "gis-skripsi-free.firebasestorage.app"
    backup_file_path = "backup_firestore.json"
    
    if not os.path.exists(cred_path):
        print(f"Error: File {cred_path} tidak ditemukan!")
        sys.exit(1)
        
    if not os.path.exists(backup_file_path):
        print(f"Error: File backup {backup_file_path} tidak ditemukan! Silakan lakukan backup terlebih dahulu.")
        sys.exit(1)
        
    # 1. Inisialisasi Firebase Admin
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred, {
        'storageBucket': bucket_name
    })
    db = firestore.client()
    
    # Baca data dari file backup
    with open(backup_file_path, "r", encoding="utf-8") as f:
        backup_data = json.load(f)
        
    # 2. Pembersihan Data Saat Ini (Agar tidak duplikat/bentrok)
    print("\n[1/5] Membersihkan data saat ini...")
    
    # Hapus semua warga lama
    warga_ref = db.collection("warga")
    warga_docs = list(warga_ref.stream())
    print(f"Menghapus {len(warga_docs)} dokumen warga saat ini...")
    for doc in warga_docs:
        doc_id = doc.id
        # Hapus subkoleksi 'anggota_keluarga'
        anggota_ref = warga_ref.document(doc_id).collection("anggota_keluarga")
        for sub_doc in anggota_ref.stream():
            sub_doc.reference.delete()
        # Hapus subkoleksi 'riwayat_bansos'
        riwayat_ref = warga_ref.document(doc_id).collection("riwayat_bansos")
        for sub_doc in riwayat_ref.stream():
            sub_doc.reference.delete()
        # Hapus dokumen warga utama
        doc.reference.delete()
        
    # Hapus akun Auth virtual (*@warga.sigbansos.com) beserta dokumen di 'users'
    print("Membersihkan akun virtual warga lama di Firebase Auth...")
    auth_users_to_delete = []
    page = auth.list_users()
    while page:
        for user in page.users:
            if user.email and user.email.endswith("@warga.sigbansos.com"):
                auth_users_to_delete.append(user.uid)
                # Hapus juga dokumen di koleksi 'users'
                db.collection("users").document(user.uid).delete()
        page = page.get_next_page()
        
    if auth_users_to_delete:
        print(f"Menghapus {len(auth_users_to_delete)} akun Auth virtual warga...")
        for i in range(0, len(auth_users_to_delete), 1000):
            batch = auth_users_to_delete[i:i+1000]
            auth.delete_users(batch)
            
    print("Pembersihan data selesai.")
    
    # 3. Restorasi Firebase Auth & Koleksi 'users'
    print("\n[2/5] Merestorasi akun Firebase Auth dan koleksi 'users'...")
    restored_users = 0
    for user_backup in backup_data["users"]:
        uid = user_backup["doc_id"]
        u_data = deserialize_value(user_backup["data"])
        email = u_data.get("email")
        
        # Hanya restore jika itu adalah akun warga virtual
        if email and email.endswith("@warga.sigbansos.com"):
            try:
                auth.create_user(
                    uid=uid,
                    email=email,
                    password="123456"
                )
            except auth.EmailAlreadyExistsError:
                # Jika entah bagaimana masih ada
                pass
            
            # Simpan dokumen 'users'
            db.collection("users").document(uid).set(u_data)
            restored_users += 1
            
    print(f"Berhasil merestorasi {restored_users} akun user.")
    
    # 4. Restorasi Koleksi 'warga' beserta subkoleksinya
    print("\n[3/5] Merestorasi dokumen 'warga' dan subkoleksinya ke Firestore...")
    restored_warga = 0
    restored_anggota = 0
    restored_riwayat = 0
    
    for warga_backup in backup_data["warga"]:
        doc_id = warga_backup["doc_id"]
        w_data = deserialize_value(warga_backup["data"])
        subcols = warga_backup["subcollections"]
        
        # Simpan dokumen warga utama dengan ID yang sama!
        warga_ref.document(doc_id).set(w_data)
        restored_warga += 1
        
        # Simpan subkoleksi 'anggota_keluarga'
        for sub_item in subcols.get("anggota_keluarga", []):
            sub_id = sub_item["id"]
            sub_data = deserialize_value(sub_item["data"])
            warga_ref.document(doc_id).collection("anggota_keluarga").document(sub_id).set(sub_data)
            restored_anggota += 1
            
        # Simpan subkoleksi 'riwayat_bansos'
        for sub_item in subcols.get("riwayat_bansos", []):
            sub_id = sub_item["id"]
            sub_data = deserialize_value(sub_item["data"])
            warga_ref.document(doc_id).collection("riwayat_bansos").document(sub_id).set(sub_data)
            restored_riwayat += 1
            
    print(f"Berhasil merestorasi:")
    print(f"- {restored_warga} Kepala Keluarga (Warga Utama)")
    print(f"- {restored_anggota} Anggota Keluarga")
    print(f"- {restored_riwayat} Riwayat Bansos")
    
    # 5. Restorasi Foto ke Firebase Storage (jika terhapus)
    print("\n[4/5] Memeriksa dan merestorasi foto rumah di Firebase Storage...")
    backup_photos_dir = "backup_photos"
    
    if os.path.exists(backup_photos_dir):
        try:
            bucket = storage.bucket()
            files = os.listdir(backup_photos_dir)
            upload_count = 0
            
            for file_name in files:
                local_file_path = os.path.join(backup_photos_dir, file_name)
                if os.path.isfile(local_file_path):
                    blob_path = f"foto_rumah/{file_name}"
                    blob = bucket.blob(blob_path)
                    
                    # Upload hanya jika file tidak ada di storage
                    if not blob.exists():
                        print(f"Mengupload kembali: {local_file_path} -> {blob_path}")
                        blob.upload_from_filename(local_file_path)
                        upload_count += 1
                        
            print(f"Selesai! Berhasil mengupload ulang {upload_count} foto ke Storage.")
        except Exception as e:
            print(f"Error saat merestorasi foto ke Storage: {e}")
    else:
        print("Folder backup_photos tidak ditemukan, melewati restorasi foto.")
        
    print("\n[5/5] Proses Restorasi Selesai dengan Sukses!")
    print("Data penduduk riil, koordinat rumah, dan foto telah dikembalikan seperti semula.")

if __name__ == "__main__":
    main()
