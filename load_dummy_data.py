import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore, auth

def main():
    print("=== Memulai Script Pembersihan & Pengisian Data Dummy Sidang ===")
    
    cred_path = "serviceAccountKey.json"
    if not os.path.exists(cred_path):
        print(f"Error: File {cred_path} tidak ditemukan!")
        sys.exit(1)
        
    # 1. Inisialisasi Firebase
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # 2. Pembersihan Data Lama (Koleksi 'warga' & Subkoleksinya, serta Auth)
    print("\n--- Membersihkan Data Lama ---")
    warga_ref = db.collection("warga")
    warga_docs = list(warga_ref.stream())
    print(f"Menghapus {len(warga_docs)} dokumen warga lama...")
    
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
            
        # Hapus warga utama
        doc.reference.delete()
    print("Selesai menghapus semua dokumen warga lama di Firestore.")
    
    # Hapus akun Auth virtual (*@warga.sigbansos.com)
    print("\nMembersihkan akun virtual warga di Firebase Auth...")
    auth_users_to_delete = []
    page = auth.list_users()
    while page:
        for user in page.users:
            if user.email and user.email.endswith("@warga.sigbansos.com"):
                auth_users_to_delete.append(user.uid)
                # Hapus dokumen users di Firestore
                db.collection("users").document(user.uid).delete()
        page = page.get_next_page()
        
    if auth_users_to_delete:
        print(f"Menghapus {len(auth_users_to_delete)} akun Auth virtual lama...")
        for i in range(0, len(auth_users_to_delete), 1000):
            batch = auth_users_to_delete[i:i+1000]
            auth.delete_users(batch)
        print("Selesai membersihkan akun Auth virtual.")
    else:
        print("Tidak ada akun virtual lama untuk dihapus.")
        
    # 3. Membuat Data Dummy Sidang (10 KK)
    # Kami menyebarkan koordinat di dalam batas RT 02 Tegalsari (sekitar Lat: -6.8483 s/d -6.8498, Lng: 107.9277 s/d 107.9306)
    print("\n--- Memulai Pembuatan Data Dummy Sidang ---")
    
    # Beberapa URL foto riil dari backup agar saat demo gambarnya tampil bagus
    real_photos = [
        "https://firebasestorage.googleapis.com/v0/b/gis-skripsi-free.firebasestorage.app/o/foto_rumah%2Ffoto_3211180101670008_1783398351007.jpg?alt=media&token=29a2ad6c-9be0-490f-8d60-b61202558322",
        "https://firebasestorage.googleapis.com/v0/b/gis-skripsi-free.firebasestorage.app/o/foto_rumah%2Ffoto_3211182810500002_1783398231137.jpg?alt=media&token=61028bdf-f935-401e-bca8-158c9c0c0f05",
        "https://firebasestorage.googleapis.com/v0/b/gis-skripsi-free.firebasestorage.app/o/foto_rumah%2Ffoto_3211180808670010_1783397995487.jpg?alt=media&token=fbda0785-0b82-488a-8c3f-2f78eae1b6c6",
        "https://firebasestorage.googleapis.com/v0/b/gis-skripsi-free.firebasestorage.app/o/foto_rumah%2Ffoto_3211181008870008_1783398404002.jpg?alt=media&token=2f7eda91-da9c-4020-b212-c66e77193012",
        "https://firebasestorage.googleapis.com/v0/b/gis-skripsi-free.firebasestorage.app/o/foto_rumah%2Ffoto_3211172812910005_1783401827764.jpg?alt=media&token=98306e49-b7a8-4ac7-b855-e314f4c6ca30"
    ]
    
    dummy_warga = [
        {
            "nama": "Ahmad Subarjo",
            "nik": "3211020101900001",
            "no_kk": "3211020101909991",
            "blok": "Blok A",
            "lokasi": firestore.GeoPoint(-6.848500, 107.928100),
            "menerima_bantuan": "Ya",
            "jenis_bantuan": "BPNT",
            "status_cair": "Sudah Menerima",
            "foto_url": real_photos[0],
            "anggota": [
                {"nama": "Ratna Sari", "nik": "3211020101900011", "jenis_kelamin": "Wanita", "hubungan": "Istri"},
                {"nama": "Dodi Subarjo", "nik": "3211020101900012", "jenis_kelamin": "Pria", "hubungan": "Anak"}
            ]
        },
        {
            "nama": "Siti Aminah",
            "nik": "3211020101900002",
            "no_kk": "3211020101909992",
            "blok": "Blok A",
            "lokasi": firestore.GeoPoint(-6.848800, 107.928500),
            "menerima_bantuan": "Ya",
            "jenis_bantuan": "PKH",
            "status_cair": "Belum Menerima",
            "foto_url": real_photos[1],
            "anggota": [
                {"nama": "Muhammad Yusuf", "nik": "3211020101900021", "jenis_kelamin": "Pria", "hubungan": "Lainnya"}, # Suami
                {"nama": "Aisyah Yusuf", "nik": "3211020101900022", "jenis_kelamin": "Wanita", "hubungan": "Anak"}
            ]
        },
        {
            "nama": "Joko Widodo",
            "nik": "3211020101900003",
            "no_kk": "3211020101909993",
            "blok": "Blok B",
            "lokasi": firestore.GeoPoint(-6.849100, 107.928200),
            "menerima_bantuan": "Ya",
            "jenis_bantuan": "BLT",
            "status_cair": "Sudah Menerima",
            "foto_url": real_photos[2],
            "anggota": [
                {"nama": "Iriana", "nik": "3211020101900031", "jenis_kelamin": "Wanita", "hubungan": "Istri"},
                {"nama": "Gibran", "nik": "3211020101900032", "jenis_kelamin": "Pria", "hubungan": "Anak"},
                {"nama": "Kaesang", "nik": "3211020101900033", "jenis_kelamin": "Pria", "hubungan": "Anak"}
            ]
        },
        {
            "nama": "Bambang Hermawan",
            "nik": "3211020101900004",
            "no_kk": "3211020101909994",
            "blok": "Blok B",
            "lokasi": firestore.GeoPoint(-6.849300, 107.928900),
            "menerima_bantuan": "Tidak",
            "jenis_bantuan": "-",
            "status_cair": "Belum Menerima",
            "foto_url": real_photos[3],
            "anggota": [
                {"nama": "Sri Mulyani", "nik": "3211020101900041", "jenis_kelamin": "Wanita", "hubungan": "Istri"}
            ]
        },
        {
            "nama": "Dewi Lestari",
            "nik": "3211020101900005",
            "no_kk": "3211020101909995",
            "blok": "Blok C",
            "lokasi": firestore.GeoPoint(-6.849500, 107.929200),
            "menerima_bantuan": "Tidak",
            "jenis_bantuan": "-",
            "status_cair": "Belum Menerima",
            "foto_url": real_photos[4],
            "anggota": [
                {"nama": "Arka Lestari", "nik": "3211020101900051", "jenis_kelamin": "Pria", "hubungan": "Anak"}
            ]
        },
        {
            "nama": "Hendra Wijaya",
            "nik": "3211020101900006",
            "no_kk": "3211020101909996",
            "blok": "Blok C",
            "lokasi": firestore.GeoPoint(-6.848400, 107.929800),
            "menerima_bantuan": "Ya",
            "jenis_bantuan": "BPNT",
            "status_cair": "Belum Menerima",
            "foto_url": "",
            "anggota": [
                {"nama": "Lilis Wijaya", "nik": "3211020101900061", "jenis_kelamin": "Wanita", "hubungan": "Istri"}
            ]
        },
        {
            "nama": "Rina Kartika",
            "nik": "3211020101900007",
            "no_kk": "3211020101909997",
            "blok": "Blok D",
            "lokasi": firestore.GeoPoint(-6.848900, 107.930200),
            "menerima_bantuan": "Ya",
            "jenis_bantuan": "PKH",
            "status_cair": "Sudah Menerima",
            "foto_url": "",
            "anggota": [
                {"nama": "Tono", "nik": "3211020101900071", "jenis_kelamin": "Pria", "hubungan": "Lainnya"}
            ]
        },
        {
            "nama": "Agus Setiawan",
            "nik": "3211020101900008",
            "no_kk": "3211020101909998",
            "blok": "Blok D",
            "lokasi": firestore.GeoPoint(-6.849300, 107.930000),
            "menerima_bantuan": "Tidak",
            "jenis_bantuan": "-",
            "status_cair": "Belum Menerima",
            "foto_url": "",
            "anggota": [
                {"nama": "Ani Setiawan", "nik": "3211020101900081", "jenis_kelamin": "Wanita", "hubungan": "Istri"}
            ]
        },
        {
            "nama": "Eko Prasetyo",
            "nik": "3211020101900009",
            "no_kk": "3211020101909999",
            "blok": "Blok E",
            "lokasi": firestore.GeoPoint(-6.849600, 107.929700),
            "menerima_bantuan": "Ya",
            "jenis_bantuan": "BLT",
            "status_cair": "Belum Menerima",
            "foto_url": "",
            "anggota": [
                {"nama": "Puji Prasetyo", "nik": "3211020101900091", "jenis_kelamin": "Wanita", "hubungan": "Istri"}
            ]
        },
        {
            "nama": "Lani Wijaya",
            "nik": "3211020101900010",
            "no_kk": "3211020101909910",
            "blok": "Blok E",
            "lokasi": firestore.GeoPoint(-6.849200, 107.929500),
            "menerima_bantuan": "Tidak",
            "jenis_bantuan": "-",
            "status_cair": "Belum Menerima",
            "foto_url": "",
            "anggota": [
                {"nama": "Rudi Wijaya", "nik": "3211020101900101", "jenis_kelamin": "Pria", "hubungan": "Lainnya"}
            ]
        }
    ]
    
    imported_families = 0
    imported_members = 0
    
    for warga in dummy_warga:
        nik = warga["nik"]
        no_kk = warga["no_kk"]
        
        # Siapkan payload
        warga_payload = {
            'nama': warga["nama"],
            'nik': nik,
            'no_kk': no_kk,
            'blok': warga["blok"],
            'lokasi': warga["lokasi"],
            'menerima_bantuan': warga["menerima_bantuan"],
            'jenis_bantuan': warga["jenis_bantuan"],
            'status_cair': warga["status_cair"],
            'foto_url': warga["foto_url"],
            'tanggal_diterima': firestore.SERVER_TIMESTAMP if warga["status_cair"] == "Sudah Menerima" else None,
            'tanggal_input': firestore.SERVER_TIMESTAMP
        }
        
        # Simpan ke Firestore
        _, doc_ref = warga_ref.add(warga_payload)
        doc_id = doc_ref.id
        
        # Simpan Subkoleksi anggota_keluarga
        for member in warga["anggota"]:
            member_payload = {
                'nik': member["nik"],
                'nama': member["nama"],
                'no_kk': no_kk,
                'jenis_kelamin': member["jenis_kelamin"],
                'hubungan': member["hubungan"]
            }
            warga_ref.document(doc_id).collection("anggota_keluarga").add(member_payload)
            imported_members += 1
            
        # Simpan Subkoleksi riwayat_bansos jika sudah menerima
        if warga["status_cair"] == "Sudah Menerima":
            riwayat_payload = {
                'jenis_bantuan': warga["jenis_bantuan"],
                'status_cair': warga["status_cair"],
                'tanggal_diterima': firestore.SERVER_TIMESTAMP
            }
            warga_ref.document(doc_id).collection("riwayat_bansos").add(riwayat_payload)
            
        # Buat Akun Auth Virtual
        virtual_email = f"{nik}@warga.sigbansos.com"
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
            
        # Simpan role di Firestore koleksi 'users'
        db.collection("users").document(uid).set({
            'email': virtual_email,
            'role': 'user',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        imported_families += 1
        print(f"Berhasil mengimpor Dummy KK: {warga['nama']} ({nik})")
        
    print("\n=== Proses Selesai ===")
    print(f"Total KK dummy dibuat: {imported_families}")
    print(f"Total Anggota Keluarga dummy dibuat: {imported_members}")
    print("Semua akun virtual warga dummy berhasil dibuat dengan password default: 123456")
    print("Lokasi koordinat telah disebar di dalam poligon RT 02 Tegalsari.")

if __name__ == "__main__":
    main()
