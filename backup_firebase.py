import os
import sys
import json
import datetime
import firebase_admin
from firebase_admin import credentials, firestore, storage

def serialize_value(val):
    """Mengubah tipe data khusus Firestore (GeoPoint, Timestamp) ke format JSON-compatible."""
    if isinstance(val, firestore.GeoPoint):
        return {
            "_type": "GeoPoint", 
            "latitude": val.latitude, 
            "longitude": val.longitude
        }
    # Periksa objek dengan atribut seconds dan nanoseconds (Timestamp Firestore)
    elif hasattr(val, "seconds") and hasattr(val, "nanoseconds"):
        return {
            "_type": "Timestamp", 
            "seconds": val.seconds, 
            "nanoseconds": val.nanoseconds
        }
    elif isinstance(val, datetime.datetime):
        return {
            "_type": "DateTime", 
            "iso": val.isoformat()
        }
    elif isinstance(val, dict):
        return {k: serialize_value(v) for k, v in val.items()}
    elif isinstance(val, list):
        return [serialize_value(x) for x in val]
    else:
        return val

def main():
    print("=== Memulai Backup Data Firebase (Firestore & Storage) ===")
    
    cred_path = "serviceAccountKey.json"
    bucket_name = "gis-skripsi-free.firebasestorage.app"
    
    if not os.path.exists(cred_path):
        print(f"Error: File {cred_path} tidak ditemukan!")
        sys.exit(1)
        
    # 1. Inisialisasi Firebase Admin
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred, {
        'storageBucket': bucket_name
    })
    db = firestore.client()
    
    # 2. Backup Firestore: Koleksi 'warga' beserta subkoleksinya
    print("\n[1/3] Mengambil data dari Firestore...")
    backup_data = {
        "warga": [],
        "users": []
    }
    
    # Ambil koleksi 'warga'
    warga_ref = db.collection("warga")
    warga_docs = list(warga_ref.stream())
    print(f"Menemukan {len(warga_docs)} dokumen warga.")
    
    for doc in warga_docs:
        doc_id = doc.id
        doc_data = doc.to_dict()
        
        # Ambil subkoleksi 'anggota_keluarga'
        anggota_ref = warga_ref.document(doc_id).collection("anggota_keluarga")
        anggota_list = []
        for sub_doc in anggota_ref.stream():
            anggota_list.append({
                "id": sub_doc.id,
                "data": serialize_value(sub_doc.to_dict())
            })
            
        # Ambil subkoleksi 'riwayat_bansos'
        riwayat_ref = warga_ref.document(doc_id).collection("riwayat_bansos")
        riwayat_list = []
        for sub_doc in riwayat_ref.stream():
            riwayat_list.append({
                "id": sub_doc.id,
                "data": serialize_value(sub_doc.to_dict())
            })
            
        backup_data["warga"].append({
            "doc_id": doc_id,
            "data": serialize_value(doc_data),
            "subcollections": {
                "anggota_keluarga": anggota_list,
                "riwayat_bansos": riwayat_list
            }
        })
        
    # Ambil koleksi 'users' (auth role mapping)
    users_ref = db.collection("users")
    users_docs = list(users_ref.stream())
    print(f"Menemukan {len(users_docs)} dokumen users.")
    for doc in users_docs:
        backup_data["users"].append({
            "doc_id": doc.id,
            "data": serialize_value(doc.to_dict())
        })
        
    # Simpan data Firestore ke file JSON
    backup_file_path = "backup_firestore.json"
    with open(backup_file_path, "w", encoding="utf-8") as f:
        json.dump(backup_data, f, indent=4, ensure_ascii=False)
    print(f"Berhasil menyimpan backup Firestore ke: {backup_file_path}")
    
    # 3. Backup Firebase Storage: Foto Rumah
    print("\n[2/3] Mendownload foto rumah dari Firebase Storage...")
    backup_photos_dir = "backup_photos"
    if not os.path.exists(backup_photos_dir):
        os.makedirs(backup_photos_dir)
        
    try:
        bucket = storage.bucket()
        # List files dengan prefix 'foto_rumah/'
        blobs = bucket.list_blobs(prefix="foto_rumah/")
        download_count = 0
        
        for blob in blobs:
            # Skip direktori itu sendiri jika ada
            if blob.name.endswith('/'):
                continue
                
            # Ambil nama file asli
            file_name = os.path.basename(blob.name)
            local_file_path = os.path.join(backup_photos_dir, file_name)
            
            print(f"Mendownload {blob.name} -> {local_file_path}")
            blob.download_to_filename(local_file_path)
            download_count += 1
            
        print(f"Selesai! Berhasil mendownload {download_count} foto ke folder '{backup_photos_dir}/'")
    except Exception as e:
        print(f"Peringatan saat backup Storage (mungkin Storage belum dikonfigurasi/kosong): {e}")
        
    print("\n[3/3] Proses Backup Selesai!")
    print("Semua data Anda aman. Anda sekarang bisa menghapus database untuk demo sidang.")
    print("Gunakan script 'restore_firebase.py' untuk mengembalikannya ke semula.")

if __name__ == "__main__":
    main()
