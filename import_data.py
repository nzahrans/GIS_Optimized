import os
import sys
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore, auth

def main():
    print("=== Memulai Script Pembersihan & Import Data Warga ===")
    
    # 1. Inisialisasi Firebase Admin SDK
    cred_path = "serviceAccountKey.json"
    if not os.path.exists(cred_path):
        print(f"Error: File {cred_path} tidak ditemukan!")
        sys.exit(1)
        
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # 2. Pembersihan Data Lama di Firestore dan Auth
    print("\n--- Membersihkan Data Lama ---")
    
    # Hapus semua dokumen di koleksi 'warga' beserta subkoleksinya
    warga_ref = db.collection("warga")
    warga_docs = list(warga_ref.stream())
    print(f"Menemukan {len(warga_docs)} dokumen warga lama untuk dihapus.")
    
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
    print("Selesai menghapus semua dokumen warga di Firestore.")
    
    # Hapus akun Auth virtual (*@warga.sigbansos.com)
    print("\nMencari akun virtual warga di Firebase Auth untuk dihapus...")
    auth_users_to_delete = []
    
    # List all users in Firebase Auth (max 1000 per page, should be enough)
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
        # Batch delete auth users (max 1000 per batch)
        for i in range(0, len(auth_users_to_delete), 1000):
            batch = auth_users_to_delete[i:i+1000]
            auth.delete_users(batch)
        print("Selesai menghapus akun Auth virtual warga.")
    else:
        print("Tidak ada akun virtual warga lama di Firebase Auth.")

    # 3. Membaca & Memproses Excel
    print("\n--- Membaca dan Memfilter Data Excel ---")
    excel_path = "Data Warga Tegalsari.xls"
    if not os.path.exists(excel_path):
        print(f"Error: File {excel_path} tidak ditemukan!")
        sys.exit(1)
        
    df = pd.read_excel(excel_path)
    
    # Filter RT 02 dan RW 02
    df_filtered = df[(df['NO_RT'] == 2) & (df['NO_RW'] == 2)].copy()
    print(f"Total baris warga di RT 02 RW 02: {len(df_filtered)}")
    
    # Normalisasi tipe data NIK dan NO_KK menjadi string bersih tanpa spasi
    df_filtered['NIK'] = df_filtered['NIK'].astype(str).str.strip().str.replace(r'\.0$', '', regex=True)
    df_filtered['NO_KK'] = df_filtered['NO_KK'].astype(str).str.strip().str.replace(r'\.0$', '', regex=True)
    
    # Group by NO_KK
    grouped = df_filtered.groupby('NO_KK')
    
    total_families = len(grouped)
    print(f"Jumlah Kartu Keluarga (KK) unik: {total_families}")
    
    print("\n--- Memulai Import Data Baru ---")
    imported_families = 0
    imported_members = 0
    
    for no_kk, group in grouped:
        # Cari Kepala Keluarga (HUB_KELUARGA == 'Kepala Kel')
        kk_row = group[group['HUB_KELUARGA'].str.lower().str.contains('kepala', na=False)]
        
        if kk_row.empty:
            # Jika tidak ditemukan, ambil anggota pertama sebagai kepala keluarga
            kk_row = group.iloc[[0]]
            
        kk_idx = kk_row.index[0]
        kk_data = kk_row.loc[kk_idx]
        
        # Anggota keluarga lainnya (baris yang bukan KK)
        anggota_rows = group.drop(kk_idx)
        
        # Siapkan data Warga Utama (Kepala Keluarga)
        warga_payload = {
            'nama': str(kk_data['NAMA_PANJANG']).strip(),
            'nik': str(kk_data['NIK']).strip(),
            'no_kk': str(kk_data['NO_KK']).strip(),
            'blok': '',
            'lokasi': firestore.GeoPoint(-6.850071, 107.930230),  # Koordinat default
            'menerima_bantuan': 'Tidak',
            'jenis_bantuan': '-',
            'status_cair': 'Belum Menerima',
            'foto_url': '',
            'tanggal_diterima': None,
            'tanggal_input': firestore.SERVER_TIMESTAMP
        }
        
        # Simpan ke Firestore
        _, doc_ref = warga_ref.add(warga_payload)
        warga_doc_id = doc_ref.id
        
        # Buat Akun Auth Virtual untuk Kepala Keluarga
        virtual_email = f"{kk_data['NIK'].strip()}@warga.sigbansos.com"
        virtual_password = "123456"
        
        try:
            user = auth.create_user(
                email=virtual_email,
                password=virtual_password
            )
            uid = user.uid
        except auth.EmailAlreadyExistsError:
            user = auth.get_user_by_email(virtual_email)
            uid = user.uid
            
        # Simpan role user di Firestore koleksi 'users'
        db.collection("users").document(uid).set({
            'email': virtual_email,
            'role': 'user',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Simpan Anggota Keluarga lainnya ke subcollection 'anggota_keluarga'
        for _, member in anggota_rows.iterrows():
            # Pemetaan Jenis Kelamin (1 -> Pria, 2 -> Wanita)
            jk_val = member['JENIS_KELAMIN']
            jenis_kelamin = 'Pria'
            if str(jk_val) == '2' or str(jk_val).lower().startswith('w') or str(jk_val).lower().startswith('puan'):
                jenis_kelamin = 'Wanita'
                
            # Pemetaan Hubungan Keluarga
            hub_raw = str(member['HUB_KELUARGA']).lower()
            hubungan = 'Lainnya'
            if 'istri' in hub_raw:
                hubungan = 'Istri'
            elif 'anak' in hub_raw:
                hubungan = 'Anak'
            elif 'mertua' in hub_raw or 'orang tua' in hub_raw or 'bapak' in hub_raw or 'ibu' in hub_raw:
                hubungan = 'Orang Tua'
                
            anggota_payload = {
                'nik': str(member['NIK']).strip(),
                'nama': str(member['NAMA_PANJANG']).strip(),
                'no_kk': str(member['NO_KK']).strip(),
                'jenis_kelamin': jenis_kelamin,
                'hubungan': hubungan
            }
            
            warga_ref.document(warga_doc_id).collection("anggota_keluarga").add(anggota_payload)
            imported_members += 1
            
        imported_families += 1
        if imported_families % 10 == 0 or imported_families == total_families:
            print(f"Progress: Berhasil mengimpor {imported_families}/{total_families} keluarga.")
            
    print("\n=== Proses Selesai ===")
    print(f"Total Kepala Keluarga diimpor: {imported_families}")
    print(f"Total Anggota Keluarga diimpor: {imported_members}")
    print(f"Total keseluruhan warga terdaftar: {imported_families + imported_members}")
    print("Semua akun virtual warga berhasil dibuat dengan password default: 123456")

if __name__ == "__main__":
    main()
