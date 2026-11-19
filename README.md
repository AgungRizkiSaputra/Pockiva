# Tabungan Pribadi

Aplikasi mobile tabungan pribadi (Flutter + Supabase) untuk Gen Z dan Milenial Muda dengan pencatatan transaksi di bawah 5 detik, visualisasi progres tabungan, Smart Budget Insights, gamifikasi streak & lencana, mode gelap, sinkronisasi offline terenkripsi, dan keamanan PIN 6-digit berbasis Argon2id.

## Fitur Utama

- **Autentikasi & Keamanan**: Google OAuth (PKCE), PIN 6-digit dengan hashing Argon2id di Supabase Edge Functions, rate limiting & lockout 15 menit, Row Level Security (RLS) pada seluruh tabel, dan auto-logout setelah 15 menit tidak aktif.
- **Dashboard & Progres Tabungan**: Ringkasan saldo tabungan, persentase target, grafik perkembangan bulanan, dan status arus kas bulan berjalan.
- **Quick Add (< 5 Detik)**: Bottom sheet dengan numpad kustom (termasuk pintasan `000` untuk Rupiah), ikon kategori, pencegahan duplikasi submit (`client_id`), dan antrean sinkronisasi offline terenkripsi.
- **Riwayat Transaksi**: Dikelompokkan per tanggal, filter tipe, detail/ubah/hapus transaksi, dan pagination.
- **Smart Budget Insights**: Grafik batang perbandingan Tabungan vs Pengeluaran 6 bulan terakhir, rincian kategori, dan insight berbasis data transaksi asli.
- **Gamifikasi & Pengingat**: Daily activity streak, 8 lencana pencapaian berbasis trigger database, serta pengingat adaptif via Firebase Cloud Messaging.
- **Desain & Aksesibilitas**: Palet Sand (`#F4EFEA`), Sage (`#8A9A5B`), Electric Blue (`#007BFF`), tipografi Plus Jakarta Sans, sistem grid 8px, kontras WCAG 2.1 AA, Light & Dark Mode, serta layout responsif Mobile & Tablet/Desktop.

## Dokumentasi

- [Arsitektur & Keputusan Desain](docs/ARCHITECTURE.md)
- [Skema Database & Keamanan](docs/SCHEMA_AND_SECURITY.md)
- [Panduan Konfigurasi & Deployment](docs/DEPLOYMENT.md)
