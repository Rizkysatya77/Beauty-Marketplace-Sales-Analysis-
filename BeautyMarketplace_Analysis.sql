use sales_analysis_beautycosmetic;

/*
	HOW TO ACCESS SAFE MODE
*/
-- SET SQL_SAFE_UPDATES = 0;  -- SAFE MODE OFF 
-- SET SQL_SAFE_UPDATES = 1;  -- SAFE MODE ON

/* 
	RENAME COLUMN 
*/
alter table sales_analysis_beautycosmetic.product_code
rename column ï»¿product_code to product_code;

alter table sales_analysis_beautycosmetic.transactions
rename column ï»¿transaction_id to transaction_id;

/*
Modify Column 
*/
alter table transactions 
MODIFY COLUMN gross_sales DECIMAL(18, 2),
MODIFY COLUMN discount_amount DECIMAL(18, 2),
MODIFY COLUMN net_sales DECIMAL(18, 2),
MODIFY COLUMN shipping_cost DECIMAL(18, 2),
MODIFY COLUMN platform_fee DECIMAL(18, 2); 

alter table product_code 
MODIFY COLUMN production_cost DECIMAL(18, 2),
MODIFY COLUMN selling_price DECIMAL(18, 2); 

/* 
	UPDATE VALUES COLUMNS
*/
update transactions /* REMAPPING FROM return_reason */ 
set return_reason = case
		when returned_flag = 'Yes' AND return_reason = 'No' then 'Unknow'
		else return_reason
		end; 

/* 
	DROP COLUMNS 
*/
-- alter table sales_analysis
-- drop column return_reason;

/* 
	DROP TABEL 
*/
-- DROP TABLE sales_analysis;
-- DROP TABLE transactions_true;

-- Membuat tabel View karena data yang digunakan berukuran kecil hingga menengah (di bawah juta baris)
CREATE OR REPLACE VIEW `sales_analysis` AS
with Basedata as(
  select 
	ft.transaction_id,
	ft.transaction_date,
    DATE_FORMAT(STR_TO_DATE(transaction_date, '%d/%m/%Y'), '%W') AS day_of_week,
    ft.order_time,
	ft.platform ,
	ft.order_source ,
	ft.customer_id ,
	ft.customer_gender ,
	ft.customer_age ,
	ft.city_uppercase,
    CONCAT(UPPER(LEFT(ft.city_uppercase, 1)), LOWER(SUBSTRING(ft.city_uppercase, 2))) AS city,
    CONCAT(UPPER(LEFT(ft.province_true, 1)), LOWER(SUBSTRING(ft.province_true, 2))) AS province,
	ft.membership_tier,
	ft.quantity,
	ft.gross_sales,
	ft.discount_amount,
	ft.net_sales,
	ft.shipping_cost,
	ft.platform_fee,
    -- Hitung Net Profit di sini agar bisa langsung dianalisis
    (gross_sales - discount_amount - production_cost - shipping_cost - platform_fee) AS net_profit,
	ft.campaign_name ,
	ft.warehouse_origin ,
	ft.delivery_status ,
	ft.customer_rating ,
	ft.returned_flag  ,
    ft.return_reason,
    pc.product_name,
    pc.product_code,
    pc.category,
    pc.shade,
    pc.production_cost,
    pc.selling_price,
    pc.stock_qty,
    pc.rating_average,
    pc.review_count
  from 
      transactions as ft  
  left join 
      product_code as pc 
      on ft.product_code = pc.product_code
)
select *
from Basedata as bd;

/*
	Marketplace and Campaign & Discount Insight 
*/
-- Analisis Profitabilitas Marketplace
SELECT 
    platform AS Platform,
    SUM(gross_sales) AS Total_Revenue,
    SUM(net_profit) AS Total_Profit,
    ROUND(SUM(net_profit) / SUM(gross_sales) * 100, 2) AS Margin_Percentage
FROM sales_analysis
GROUP BY Platform
ORDER BY Total_Profit DESC;

-- Performance Campaign
select 
		row_number() over(ORDER BY sum(quantity) desc) as Ranking,
		campaign_name AS Campaign_Name,
		sum(quantity) AS Total_Sell,
        sum(gross_sales) AS Total_Revenue
from sales_analysis as sa
group by campaign_name;

-- Apakah diskon besar meningkatkan repeat transaction?
SELECT 
    CASE 
        WHEN discount_amount > threshold.Q3 THEN 'Diskon Sangat Besar' 
        WHEN discount_amount > threshold.Q2 and discount_amount <= threshold.Q3 THEN 'Diskon Besar' 
        WHEN discount_amount > threshold.Q1 and discount_amount <= threshold.Q2 THEN 'Diskon Sedang' 
        WHEN discount_amount > 0 and discount_amount <= threshold.Q1 THEN 'Diskon Kecil'
        ELSE 'Tanpa Diskon'
    END AS kategori_diskon,
    COUNT(DISTINCT subquery.customer_id) AS total_pelanggan,
    -- Menghitung pelanggan yang bertransaksi lebih dari 1 kali
    COUNT(DISTINCT CASE WHEN subquery.total_transaksi_per_user > 1 THEN subquery.customer_id END) AS jumlah_repeat_customer,
    -- Persentase Repeat Order
    Concat(round((COUNT(DISTINCT CASE WHEN subquery.total_transaksi_per_user > 1 THEN subquery.customer_id END) / COUNT(DISTINCT subquery.customer_id)) * 100, 2), '%')AS repeat_rate_persen
FROM (
	 -- Subquery 1: Mengambil data transaksi per pelanggan
    SELECT 
        customer_id,
        discount_amount,
        COUNT(transaction_id) OVER(PARTITION BY customer_id, product_name) AS total_transaksi_per_user
    FROM sales_analysis
) AS subquery
cross join	(
		 -- Subquery 2: Menghitung nilai threshold
		SELECT 
			MAX(CASE WHEN kuartil = 1 THEN discount_amount END) AS Q1,
			MAX(CASE WHEN kuartil = 2 THEN discount_amount END) AS Q2,
			MAX(CASE WHEN kuartil = 3 THEN discount_amount END) AS Q3
		FROM (
			select
				discount_amount,
				NTILE(3) OVER (ORDER BY discount_amount) AS kuartil
			FROM sales_analysis
            WHERE discount_amount > 0
        ) AS Qt__determination 
) AS threshold -- Subquery hanya menghasilkan 1 baris nilai threshold (kuartil)
GROUP BY kategori_diskon
order by total_pelanggan desc;

/*
	Analysis :
			   Penjualan didorong oleh akuisisi pelanggan baru secara masif melalui platform ekosistem digital Shopee dan Tiktok, dimana Shopee dan Tiktok secara total menyumbang 73,6%
               Omzet atau Revenue sebesar Rp 837,9 Juta dari total omzet bisnis Rp 1,13 Millyar. Penjualan bisnis product Beauty Cosmetic sangat bergantung pada ekosistem e-commerce / social commerce digital yang didorong oleh strategi promosi (campaign driven). 
               dengan audiens terbesar berada di platform Shopee dan Tiktok. Strategi Campaign dan kampanye agrsif discount (Flash Sale, Big Sale dll) telah terbagi secara sehat. Namun terdapat
               paradoks mengenai discount, dimana Besaran discount yang diberikan tidak ikut mempengaruhi loyalitas pelanggan. Meskipun diskon besar efektif memicu volume transaksi dari pemburu 
               harga (price-hunter), kelompok ini justru memiliki tingkat pembelian ulang (repeat rate) terendah (11,76%). Sebaliknya, kelompok diskon kecil mencatat repeat rate tertinggi (12,55%).
               
               Campaign Flash Sale menjadi Campaign peringkat ke-1 dengan total selling terbanyak yaitu 1357, namun Beauty Festival menjadi Campaign dengan penyumbang kontribusi revenue terbanyak
               sebesar Rp 205,461,609. Hal ini kemungkinan karena produk berada pada kategori Beauty / Skincare / Fashion, kategori ini sangat cocok dengan audiens di platform Tiktok (yang impulsif 
               karena video/live/content) atau Shopee (video/live/ulasan). Strategi Campaign yang menyangkut tentang Kecantikan terbukti menghasilkan revenue atau Average Order Value (AOV) yang lebih
               tinggi dibandingkan dengan Flash Sale biasa.
               
               Saat tidak ada Campaign (No Campaign) pun, Total Selling product tetap mampu menjual 1082 unit dan menghasilkan Revenue sebesar Rp 164 Jt. Sementara itu, kanal Offline Store dan Website 
               memberikan kontribusi gabungan sekitar 26,5% dari total revenue. Hal ini mengindikasikan bahwa jika tidak ada Campaign (No Campaign) pun, performa penjualan pada Website / Offline Store
               menunjukkan adanya organic baseline demand (permintaan dasar yang sehat). Artinya konsumen tidak hanya membeli product karena faktor Discount atau Campaign, melaikan karena mereka
               butuh product tersebut. Hal ini mengindikasikan bahwa Audiens Website dan Offline Store merupakan pelanggan setia (Loyalist) yang melakukan repurchase (pembelian ulang) tanpa perlu menunggu Discount, 
               Flash Sale ataupun Big Sale.
               
	Rekomendasi Strategi :  
							- Efisiensi Anggaran : Mengurangi porsi discount Besar secara bertahap untuk menghindaari penurunan repeat rate, Alokasikan ke Campaign lainnya dengan
												   nilai tambah paket building ataupun reward langsung. Dengan menggunakan pendekatan layanan atau keuntungan ekslusif, guna mendongkrak
                                                   repeate rate kelompok pelanggan royal (Discount Kecil-Sedang, Website dan Offline) agar bisa naik ke angka > 20%
*/

-- Performance Comparasion Marketplace and Customer Rating
select 
	  ROW_NUMBER() OVER (ORDER BY sum(gross_sales) Desc) as Ranking,
	  platform AS Platform,
      sum(selling_price) AS Total_HargaJual_Barang,
      sum(quantity) AS Total_Terjual,
      sum(production_cost) AS Total_Biaya_Produksi,
      sum(shipping_cost) AS Total_Biaya_Pengiriman,
      sum(platform_fee) AS Total_Platform_Fee,
	  sum(discount_amount) AS Total_discount_amount,
      sum(gross_sales) AS Total_Revenue, 
      sum(net_profit) AS Total_Profit,
      round(avg(customer_rating), 2) AS Avg_Rating_Customer
from sales_analysis as sa
group by platform;

-- Performa Sales By Gender
select 
	  ROW_NUMBER() OVER (ORDER BY sum(gross_sales) Desc) as Ranking,
	  platform AS Platform,
      customer_gender AS Customer_Gender,
      sum(quantity) AS Total_Terjual,
	  sum(gross_sales) AS Total_Revenue, 
      sum(net_profit) AS  Total_Profit,
      /*
      -- CONCAT('Rp ', FORMAT(sum(production_cost), 2)) AS Biaya_Produksi,
      -- CONCAT('Rp ', FORMAT(sum(selling_price), 2)) AS Harga_jual,
      -- CONCAT('Rp ', FORMAT(sum(shipping_cost), 2)) AS Biaya_Pengiriman,
      -- CONCAT('Rp ', FORMAT(sum(platform_fee), 2)) AS Platform_Fee,
      -- CONCAT((sum(discount_amount)/100)*100,"%") AS Total_Diskon,
      */
      round(avg(customer_rating), 2) AS Avg_Rating_Customer
from sales_analysis as sa
group by platform, customer_gender;

/*
	Analysis : 
				Secara keseluruhan, adanya anomali kepuasan pelanggan (rating) yang berbanding terbalik antar gender dan platform (kanal penjualan). Karena kontradiktif (omnichannel paradox)
				dimana segmen Female mendominasi pembelian secara Online namun memiliki rating terendah, sementara segmen Male mendominasi pasar Offline namun memberikan rating terendah. Rating bisnis
                tertahan diangka kritis (2.9 - 3.11 dari skala 5), artinya ada kejanggalan yang kontras dalam pemenuhan ekspektasi pelanggan yang terkait dengan Service, Produk atau Operasional
                Bisnis.
                
                Volume penjualan yang masif membuktikan bahwa traksi pasar digital terbukti sangat kuat dan sehat secara profitabilitas. Campaign digital yang digunakan sukses menarik pasar
                Female yang implusif dalam berbelanja online. Namun mereka memiliki ekspektasi detail product yang tinggi terutama saat membeli barang melalui online. Jika ada ketidaksesuaian (gap) dengan
                ekspektasi mereka, misalnya adanya keterlambatan pengiriman, barang rusak ketika sampai karena pengiriman atau warna, ukuran, bahan tidak sesuai dengan foto, video atau deskripsi pejelasan product. Hal ini yang membuat mereka 
                tidak segan untuk memberikan rating rendah. Akan tetapi berkebalikan jika segmen Female berbelanja secara offline, mereka tidak segan untuk memberikan rating tinggi 3.11. 
                Hal ini karena ekspektasi mereka bisa terpenuhi karena bisa melihat product secara langsung, menyentuh bahkan mencoba product tersebut yang menghilangkan keraguan dan ketidakpastian.
                Namun terbalik dengan segmen Male, mereka memberikan rating tertinggi sebesar 3.04 dalam berbelanja secara online. Hal ini mungkin karena effisiensi, cepat dan tanpa ribet. Faktor tersebut
                menjadi acuan segemen Male untuk memberikan rating tinggi. Akan tetapi jika segmen Male diberikan pilihan untuk berbelanja secara offline (toko fisik), jika ekspektasi mereka terhadap
                service atau kemudahan tidak terpenuhi (misal : antrian lama, stock habis dan service yang kurang sigap). Maka mereka tidak segan untuk memberikan reting lebih rendah (2.97-2.98)
                
				Berdasarkan data, Website menjadi platform paling efisien (Most Profitable Channel) dengan Cost shipping terendah (3,28%) dan Biaya plafform paling minim (1,74%). Meskipun
                secara volume penjulan paling kecil, namun profit margin bersihnya paling besar yaitu 67,99%. Sementara itu Tiktok menjadi platform paling menguras Margin paling besar, dimana
                untuk biaya shipping memakan margin sebanyak 3,33% dan fee platform 12,88%. Hal ini berimplikasi pada margin keutungan menjadi yang paling rendah yaitu 66,46%. Akan tetapi
                Shoppe menjadi Best All-Rounder dalam volume penjualan dan efisiensi biaya, dengan fee platform sebesar 12,11% menghasilkan margin keutungan yang sehat dan ke-2 terbesar yaitu 67,47% hanya 
                selisih tipis dari website. Namun untuk toko offline menjadi platform dengan biaya tertinggi sebesar 13,28%, hal ini merepresentasikan cost operasional, sewa tempat, listrik,
                gaji karyawan dll. Walaupun cost operasinal lebih tinggi sedikit dari biaya pltform online, karena cost shipping yang rendah hal ini berimplikasi pada margin keuntungan yang tetap
                terjaga stabil di angka 66,79%.
    
    Rekomendasi Stratergi :
							- Audit kembali biaya vendor logistik dan packaging, hal ini untuk memastikan apakah dengan cost yang telah dialokasikan untuk packaging dan shipping. Cukup untuk 
                            memproteksi barang yang dikirim dengan benar. Maka jika dirasa kurang lebih baik menaikan sedikit cost shipping untuk biaya packaging dari pada kehilangan reputasi
                            toko akibat rating yang rendah.
                            - Alihkan sebagian anggaran untuk melakukan campaign atau iklan digital ke platform website karena memberikan profit terbesar dibanding platform lainnya, dengan 
                            target utama adalah pelanggan loyalist yang telah percaya pada product yang dijual. 
                            - Lakukan Audit kembali untuk platform online terutama Tiktok, untuk efisiensi biaya-biaya yang bisa dipangkan agar tidak memotong margin profit yang terlalu besar. 
                            - Mempertahankan Formula Operasional pada platform Shopee dengan memantau terus sistem manajemen stock, pengemasan, shipping dan keikutsertaan campaign yang dibuat
                            oleh pihak Shopee. Hal ini bisa menjadi benchmark untuk mengoptimalkan penjualan pada platform online lainnya.
*/

/*
	Product Insight
*/
-- Best Category Product Selling
select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) Desc) as Ranking,
        category AS Category,
        sum(quantity) AS Total_Terjual,
        sum(gross_sales) AS Total_Revenue,
        sum(net_profit) AS Penjualan_Bersih,
        round(avg(rating_average), 2) Product_Rating,
        sum(review_count) Review_Count
from sales_analysis as sa
group by category;

-- Best Product by profit_margin_pct
SELECT 
	ROW_NUMBER() OVER (ORDER BY ROUND(SUM(net_profit) / NULLIF(SUM(gross_sales), 0), 4) Desc) as Ranking,
    product_name,
    SUM(quantity) AS total_quantity,
    SUM(gross_sales) AS total_revenue,
    SUM(net_profit) AS total_profit,
    -- Margin percentage untuk melihat efisiensi
    ROUND(SUM(net_profit) / NULLIF(SUM(gross_sales), 0) *100, 2) AS profit_margin_pct
FROM sales_analysis 
GROUP BY product_name;

-- Top 10 Best Selling Product, Revenue and Net Sales
select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) Desc) as Ranking,
		product_name,
        sum(quantity) AS Total_Terjual,
        sum(gross_sales) AS Total_Revenue,
        sum(net_profit) AS Penjualan_Bersih,
        round(avg(rating_average), 2) Product_Rating,
        sum(review_count) Review_Count
from sales_analysis as sa
group by product_name
limit 10;

-- Top 10 Low Selling Product, Revenue and Net Sales
select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) asc) as Ranking,
		product_name,
        sum(quantity) AS Total_Terjual,
        sum(gross_sales) AS Total_Revenue,
        sum(net_profit) AS Penjualan_Bersih,
        round(avg(rating_average), 2) Product_Rating,
        sum(review_count) Review_Count
from sales_analysis as sa
group by product_name
limit 10;

-- The Most of Products ('Returned', 'Cancelled', 'Delivered')
/*
 select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) Desc) as Ranking,
        product_name AS Product_Name,
        delivery_status AS Delivery_Status, 
        sum(quantity) AS Total_Product
from sales_analysis as sa
where delivery_status = 'Delivered'
group by product_name
ORDER BY sum(quantity) Desc
;
*/
WITH Cancelled AS (
    SELECT 
        product_name AS Cancelled_Product,
        SUM(quantity) AS Cancelled_Qty,
        ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn
    FROM sales_analysis
    WHERE delivery_status = 'Cancelled'
    GROUP BY product_name
), 
Returned AS (
    SELECT 
        product_name AS Returned_Product,
        SUM(quantity) AS Returned_Qty,
        ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn
    FROM sales_analysis
    WHERE delivery_status = 'Returned'
    GROUP BY product_name
),
Delivered AS (
    SELECT 
        product_name AS Delivered_Product,
        SUM(quantity) AS Delivered_Qty,
        ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn
    FROM sales_analysis
    WHERE delivery_status = 'Delivered'
    GROUP BY product_name
)
SELECT 
    c.Cancelled_Product,
    c.Cancelled_Qty,
    r.Returned_Product,
    r.Returned_Qty,
    d.Delivered_Product,
    d.Delivered_Qty
FROM Cancelled c
INNER JOIN Returned r ON c.rn = r.rn
INNER JOIN Delivered d ON c.rn = d.rn;

-- Which products need to be restocked more quickly 
select 
		product_name AS Product_Name,
        sum(quantity) AS Total_Selling,
		sum(stock_qty) AS Stock_Qty_Awal,
        sum(stock_qty) -  sum(quantity) AS Stock_Qty_Akhir
from sales_analysis as sa
group by product_name
order by Total_Selling desc;

/*
	Analysis :
				Best Category product yang banyak terjual adalah pewarna bibir (Lipstick), dengan margin tebal (>74%) adalah penggerak utama volume akuisisi pasar platform online
                (Tiktok & Shopee). Akan tetapi akibat tingginya pengembalian barang (Returned) pada kategori product kompleks kempa-kemas (Foundation, Lipstick dan Cushion) secara masif. Hal ini
                dapat menggerus profitabilitas bisnis karena cost pengiriman bertambah. Hal ini mengindikasikn karena masalah akurasi visual/warna product pada platform online yang memicu 
                anomali kepuasaan consumen, yang dimana consumen wanita mendominasi pembelian online akan tetapi mereka memberikan rating terendah.
                
                Walaupun Lipstick Adalah Best Seller nomor 1 (1.351 unit terjual dengan omzet Rp230,2 Juta). Dengan produk seperti Lip Mousse (76,76%) dan Berry Lip Balm (75,60%) memegang 
                profit margin tertinggi dari seluruh portofolio produk. Namun mencatat angka pembatalan (Cancelled) sangat tinggi (25 unit) dan retur (15 unit), hal ini mungkin dipicu karena 
                keputusan implusif konsumen saat implusif saat Flash Sale atau karena ketidak sesuaian warna (shade) saat barang tiba. Kemudian product (Foundation & Cushion) terjual sangat
                rendah dengan profit margin yang dihasilkan sekitar (56% - 60%). Dimana product Skin Veil Foundation paling banyak diretur di seluruh lini bisnis (35 unit), disusul oleh 
                Flawless Foundation (24 unit). Hal ini mungkin terkait mengenai akurasi warna kulit (skin tone matching), karena jika dijual secara online tanpa panduan undertone yang jelas. 
                Konsumen yang membeli salah warna akan kecewa dan memberikan rating rendah, konsumen akan mengajukan retur barang yang akan membuat biaya pengiriman membengkak dan margin product 
                akan semakin tergerus oleh biaya operasional retur tersebut. Kategori Blush On dan Eyebrow Blush memegang rekor sempurna dengan Rating Produk 5 murni dari hampir 1 juta ulasan, 
                dengan angka retur menengah (15 unit). Kategori Eyebrow juga kokoh di peringkat 2 penjualan total (937 unit). Produk e-commerce yang memiliki tingkat kepuasan sempurna (Rating 5.0) 
                dan volume tinggi seperti Rosy Cheek Blush adalah senjata terbaik untuk dijadikan Produk Gimmick / Hadiah (Free Gift). Daripada memberikan "Diskon Besar" yang terbukti menurunkan 
                loyalitas konsumen (repeat rate turun ke 11,76%), lebih baik berikan promosi: "Beli Foundation Gratis Rosy Cheek Blush". Ini akan mendongkrak kepuasan transaksi secara instan.
				
                Berdasarkan data, terdapat pola anomaly antara kepuasaan produk individu dengan kepuasaan platform per gender. Perbedaan tajam tersebut membuktikan isu keterlambatan / kerusakan 
                saat pengiriman online, hal ini yang membuat mereka memberikan rating toko rendah. Untuk mengatasi masalah tersebut alokasi penempatan stock perlu dipindahkan ke Gudang fulfillment 
                logistic online terdekat untuk mempercepat durasi pengiriman dan pengemasan barang guna menyelamatkan rating toko. 
				
    Rekomendasi Strategi :
							- Untuk menekan angka retur akibat konsumen kesulitan memilih shade / warna product, perlu membuat fitur Filter AR/TRY-ON warna di Tiktok Shop atau menggunakan
							  model dengan berbagai variasi warna kulit asli tanpa tambahan filter studio yang berlebihan.
							- Tingginya pembatalan saat Campaign/iklan digital karena sifat konsumen yang implusif terhadap diskon besar (price-hunter) sebaiknya dibanding memberikan diskon
                              besar dialihkan ke Campaign/promo building menggunakan product rating tinggi seperti Blush On.
*/

/*
	Customer Insight
*/
-- Ratio (%) Customer Order By gender
select 
		customer_gender AS Customer_Gender,
        sum(quantity) AS Total_Order,
        sum(gross_sales) AS Total_Revenue,
        round(avg(customer_rating), 2) AS Customer_Rating,
        -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total quantity dari seluruh data (Male + Female). 
        concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
from sales_analysis as sa
group by customer_gender;

-- Daya Beli by Membership Tier
 select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) Desc) as Ranking,
        membership_tier AS Membership_Tier,
        customer_gender AS Customer_Gender,
        sum(quantity) AS Total_Product_Terjual,
        concat('Rp ', FORMAT(sum(gross_sales), 2)) AS Total_Revenue,
        round(avg(customer_rating), 2) AS Customer_Rating,
        -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total quantity dari seluruh data (Male + Female). 
        concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
from sales_analysis as sa
group by membership_tier, customer_gender;

-- Average Customer Rating by Age Distribution 
select 
		customer_age Customer_Age,
        count(customer_age) AS Distribution_Age,
        round(avg(customer_rating), 2) AS Customer_Rating
from sales_analysis as sa
group by customer_age
order by customer_age asc;

-- Cohort Analysis (kapan pertama kali user belanja, dan berapa yang kembali di bulan berikutnya)
WITH 
-- Langkah 1: Cari bulan pertama kali setiap user belanja (Bulan Kohort)
bulan_pertama_user AS (
    SELECT 
        customer_id,
        DATE_FORMAT(STR_TO_DATE(transaction_date, '%d/%m/%Y'), '%Y-%m-01') AS bulan_kohort
    FROM sales_analysis
),
-- Langkah 2: Gabungkan dengan data transaksi untuk menghitung jarak bulan (Bulan ke-X)
jarak_transaksi AS (
    SELECT
        sa.customer_id,
        bp.bulan_kohort,
        DATE_FORMAT(STR_TO_DATE(sa.transaction_date, '%d/%m/%Y'), '%Y-%m-01') AS bulan_transaksi,
        -- Menghitung selisih bulan antara transaksi saat ini dengan transaksi pertama
        (EXTRACT(YEAR FROM DATE_FORMAT(STR_TO_DATE(sa.transaction_date, '%d/%m/%Y'), '%Y-%m-01')) - EXTRACT(YEAR FROM bp.bulan_kohort)) * 12 +
        (EXTRACT(MONTH FROM DATE_FORMAT(STR_TO_DATE(sa.transaction_date, '%d/%m/%Y'), '%Y-%m-01')) - EXTRACT(MONTH FROM bp.bulan_kohort)) AS jarak_bulan
    FROM sales_analysis as sa
    JOIN bulan_pertama_user bp ON sa.customer_id = bp.customer_id
)
-- Langkah 3: Hitung total user unik untuk setiap bulan kohort dan jarak bulannya
SELECT 
	monthname(bulan_kohort) AS Bulan_Akuisis,
    COUNT(DISTINCT customer_id) AS total_user_baru,
    -- Menghitung Persentase(%) jumlah user yang kembali di bulan-bulan berikutnya.
    -- Dengan membandingkan user aktif bulan ke-1 dengan total user baru  
    concat(round((COUNT(DISTINCT CASE WHEN jarak_bulan = 0 THEN customer_id END) / COUNT(DISTINCT customer_id))*100, 0),'%') as bulan_0,
    concat(round((COUNT(DISTINCT CASE WHEN jarak_bulan = 1 THEN customer_id END) / COUNT(DISTINCT customer_id))*100, 0),'%') as bulan_1,
    concat(round((COUNT(DISTINCT CASE WHEN jarak_bulan = 2 THEN customer_id END) / COUNT(DISTINCT customer_id))*100, 0),'%') as bulan_2,
    concat(round((COUNT(DISTINCT CASE WHEN jarak_bulan = 3 THEN customer_id END) / COUNT(DISTINCT customer_id))*100, 0),'%') as bulan_3,
    concat(round((COUNT(DISTINCT CASE WHEN jarak_bulan = 4 THEN customer_id END) / COUNT(DISTINCT customer_id))*100, 0),'%') as bulan_4,
    concat(round((COUNT(DISTINCT CASE WHEN jarak_bulan = 5 THEN customer_id END) / COUNT(DISTINCT customer_id))*100, 0),'%') as bulan_5
	/*-- COUNT(DISTINCT CASE WHEN jarak_bulan = 0 THEN customer_id END) AS bulan_0,
--     COUNT(DISTINCT CASE WHEN jarak_bulan = 1 THEN customer_id END) AS bulan_1,
--     COUNT(DISTINCT CASE WHEN jarak_bulan = 2 THEN customer_id END) AS bulan_2,
--     COUNT(DISTINCT CASE WHEN jarak_bulan = 3 THEN customer_id END) AS bulan_3,
--     COUNT(DISTINCT CASE WHEN jarak_bulan = 4 THEN customer_id END) AS bulan_4,
--     COUNT(DISTINCT CASE WHEN jarak_bulan = 5 THEN customer_id END) AS bulan_5
*/
FROM jarak_transaksi
GROUP BY Bulan_Akuisis
ORDER BY field(Bulan_Akuisis,'January', 'February', 'March', 'April', 'May');

-- RFM Analysis & Segmentasi ('Champions','Loyal Customers','At-Risk','Hibernating')
WITH
-- Langkah 1: Hitung nilai mentah Recency, Frequency, dan Monetary untuk setiap customer
rfm_mentah AS (
    SELECT
        customer_id,
        -- Recency: Jumlah hari sejak transaksi terakhir hingga hari ini (asumsi hari ini menggunakan CURRENT_DATE)
        DATEDIFF(CURRENT_DATE, MAX(STR_TO_DATE(transaction_date, '%d/%m/%Y'))) AS nilai_recency,
        -- Frequency: Total jumlah transaksi unik
        COUNT(DISTINCT transaction_id) AS nilai_frequency,
        -- Monetary: Total nominal uang yang dihabiskan
        SUM(selling_price) AS nilai_monetary
    FROM sales_analysis
    GROUP BY customer_id
),
-- Langkah 2: Berikan skor 1-5 untuk masing-masing nilai menggunakan NTILE
rfm_skor AS (
    SELECT
        customer_id,
        nilai_recency,
        nilai_frequency,
        nilai_monetary,
        -- Untuk Recency: Semakin kecil hari (baru belanja), semakin tinggi skornya (ORDER BY ASC)
        NTILE(5) OVER (ORDER BY nilai_recency ASC) AS skor_r,
        -- Untuk Frequency: Semakin sering belanja, semakin tinggi skornya (ORDER BY DESC)
        NTILE(5) OVER (ORDER BY nilai_frequency DESC) AS skor_f,
        -- Untuk Monetary: Semakin besar belanja, semakin tinggi skornya (ORDER BY DESC)
        NTILE(5) OVER (ORDER BY nilai_monetary DESC) AS skor_m
    FROM rfm_mentah
), 
-- Langkah 3: Gabungkan skor menjadi kode RFM dan petakan ke dalam segmen bisnis
rfm_Segmentation AS(
SELECT
    customer_id,
    nilai_recency AS hari_sejak_belanja_terakhir,
    nilai_frequency AS total_transaksi,
    nilai_monetary AS total_belanja,
    CONCAT(skor_r, skor_f, skor_m) AS kode_rfm,
    CASE
        -- Champions: Baru saja belanja, sangat sering, dan belanja banyak
        WHEN skor_r >= 4 AND skor_f >= 4 AND skor_m >= 4 THEN 'Champions'
        
        -- Loyal Customers: Sering belanja dan nilai besar, meski recency-nya menengah
        WHEN skor_r >= 3 AND skor_f >= 3 AND skor_m >= 3 THEN 'Loyal Customers'
        
        -- At-Risk: Dulu sering belanja besar (F/M tinggi), tapi sudah lama tidak kembali (R rendah)
        WHEN skor_r <= 2 AND skor_f >= 3 AND skor_m >= 3 THEN 'At-Risk'
        
        -- Hibernating: Jarang belanja, nilai kecil, dan sudah lama sekali tidak transaksi
        WHEN skor_r <= 2 AND skor_f <= 2 AND skor_m <= 2 THEN 'Hibernating'
        
        -- Kelompok pelengkap jika tidak masuk 4 kategori utama di atas
        ELSE 'Customers Needing Attention'
    END AS segmen_pelanggan
FROM rfm_skor
ORDER BY nilai_monetary DESC
)
select rf.*
from rfm_Segmentation as rf
-- Filtering segmen_pelanggan ('Champions','Loyal Customers','At-Risk','Hibernating')
-- where segmen_pelanggan = 'Champions'
;

/*
Anlysis : 
			Berdasarkan data, Revenue yang didatapatkan digerakkan oleh konsumen tier Bronze (59% Ration penjualan) dan didominasi oleh pria (30% total order) yang bersifat transaksional dan 
			sensitive terhadap harga biasanya. Melalui kacamata Cohort Analysis, pola retensi repeat order consumen bulan-bulan awal berkisar antara 32%-46% secara masif dibulan ke-4 sampai ke-5 
			turun ke angka 0%. Hal ini mengindikasikan bahwa program akuisisi pelanggan baru tidak menciptakan loyalitas pelanggan untuk jangka Panjang. Kegagalan tersebut bermula dari rendahnya 
			indeks kepuasan pelanggan, tier penyumbang revenue terbesar broze(2.99) dan konsumen Wanita (2.97) kompak memberikan rating rendah. Hal ini diperparah dengan demografi usia customer, 
			customer gen-Z (17 tahun memberikan rating 2.82) sementara itu gen milenial (33 tahun, rating (2.76) dan 37 tahun, rating (2.74)) memberikan penilaian terendah karena ketidak sesuian 
			barang product yang mereka terima. Implikasi dari rusaknya siklus kepuasaan pelanggan terlihat dari hasil analysis RFM, dimana  puluhan konsumen dengan nilai belanja tinggi (monetary 
			value besar di atas Rp300.000–Rp400.000) masuk kedalam kategori At-Risk (beresiko kabur) karena telah berhenti berbelanja selama 13 hingga 37 hari terakhir ketidak puasaan pascapembelian.
			Sebaliknya kelompok Champions didominasi oleh akun-akun dengan jeda belanja lebih dari 120 hari karena history nilai belanja yang tinggi dimasa lalunya.

Rekomendasi Strategi : 
						-	Perbaikan kualitas pelayanan dengan program reaktivasi khusus (Win-back Campaign) untuk menyelamatkan pelanggan bernilai tinggi yang berstatus At-Risk sebelum mereka hilang total.
						-	Merancang benefit keuntungan Membership Tier untuk mendorong pelanggan terutama Tier Bronze naik kelas ke Silver/Gold.
						-	Membuat Campaign yang dipersonalisasi berbasis usia customer guna memperbaiki rating rendah, terutama pada segmen usia yang berpotensial menjadi customer loyalist
*/

/*
	Operational Insight
*/
-- Ratio (%) Pengembalian Barang
 select 
		returned_flag AS Returned_Flag,
        count(returned_flag) AS Total_Returned_Flag,
        -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
        concat(round((count(returned_flag) / sum(count(returned_flag)) over())*100, 0),'%') Ratio
from sales_analysis as sa
group by returned_flag;

-- Delivery Performance and Cancelled Transaction
 select 
		delivery_status AS Cancelled_Transaction,
        count(delivery_status) AS Total_Returned_Flag,
        -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
        concat(round((count(delivery_status) / sum(count(delivery_status)) over())*100, 1),'%') Ratio
from sales_analysis as sa
group by Delivery_Status;

-- Warehouse_origin shipping
select 
	  warehouse_origin AS Warehouse_Origin,
      sum(quantity) AS Total_Shipping,
	  concat('Rp ', FORMAT(SUM(shipping_cost), 0)) as Total_Shipping_Cost
from sales_analysis as sa
group by warehouse_origin
order by Total_Shipping DESC, Total_Shipping_Cost DESC;

-- Ratio Warehouse_origin by delivery_status ('Cancelled', 'Returned', 'Delivered')
WITH Cancelled AS (
    SELECT 
		  warehouse_origin AS Warehouse_Origin,
		  delivery_status,
		  sum(quantity) AS Cancelled_Shipping,
          SUM(shipping_cost) as Total_Shipping_Cost,
		  ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn,
		  -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
			concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
from sales_analysis as sa
where delivery_status = 'Cancelled'
group by warehouse_origin
), 
Returned AS (
	SELECT 
			  warehouse_origin AS Warehouse_Origin,
			  delivery_status,
			  sum(quantity) AS Returned_Shipping,
              SUM(shipping_cost) as Total_Shipping_Cost,
			  ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn,
			  -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
				concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
	from sales_analysis as sa
	where delivery_status = 'Returned'
	group by warehouse_origin
),
Delivered AS (
		SELECT 
				  warehouse_origin AS Warehouse_Origin,
				  delivery_status,
				  sum(quantity) AS Delivered_Shipping,
                  SUM(shipping_cost) as Total_Shipping_Cost,
				  ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn,
				  -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
					concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
		from sales_analysis as sa
		where delivery_status = 'Delivered'
		group by warehouse_origin
)
SELECT 
    c.Warehouse_Origin,
    c.Cancelled_Shipping,
    c.Total_Shipping_Cost,
    c.Ratio,
    r.Returned_Shipping,
    r.Total_Shipping_Cost,
    r.Ratio,
    d.Delivered_Shipping,
    d.Total_Shipping_Cost,
    d.Ratio
FROM Cancelled c
INNER JOIN Returned r ON c.rn = r.rn
INNER JOIN Delivered d ON c.rn = d.rn;

-- Total Return with Return Reason
select 
		return_reason,
        count(return_reason) AS Total_return
from sales_analysis
where return_reason != 'No'
group by return_reason
order by Total_return desc;

/*
	Analysis : 
				Meskipun rasio pengiriman sukses (Delivered) secara makro terlihat sehat sebesar 89.3%, namun secara bisnis mengalami penambahan biaya logistik terutama untuk warehouse 
                dikota Medan dan Surabaya. Hal ini akibat pembatalan dan return yang cukup tinggi,  warehouse dikota Medan dan Surabaya merupakan tempat yang paling banyak mendapatkan 
                pembatalan dan return jika diakumulasi sebesar 56% dari total kasus. Temuan ini memperkuat indikasi adanya masalah pada proses pengemasan dimana proteksi yang buruk dengan 
                perjalanan transit yang panjang, membuat paket tersebut menjadi rusak. Sehingga faktor tersebut berkontribusi langsung terhadap rendahnya rating toko maupun product yang 
                telah dianalisis sebelumnya. Sementara itu warehouse dikota Jakarta dan Bandung menunjukkan performa yang jauh lebih baik. Hal ini membuktikan bahwa manajemen operasional 
                di kedua warehouse tersebut dapat mengendalikan cost biaya dengan sangat efisien, mereka bisa dijadikan benchmarks untuk warehouse lainnya guna menekan angka retur dan 
                pembatalan. Secara geografis warehouse dikota Jakarta dan Bandung memang diuntungkan karena dekat dengan consumen dan infrastruktur logistik yang lebih matang.
                
    Rekomendasi Strategi :
							- Menetapkan standarisasi untuk pengemasan dan pengiriman, dengan cara menerapkan double bubble wrap dan menggunakan kardus yang lebih tebal untuk product yang 
                              rawan pecah dan pengiriman dengan perjalanan yang panjang.
							- Mengaudit mitra pengiriman, terutama pengiriman dari warehouse medan dan surabaya.
							- Menjadikan jakarta dan bandung sebagai warehouse fullfillment center utama agar product dapat dikirim dengan durasi yang lebih pendek hal ini bertujuan untuk 
                              menyelamatkan rating toko. 
*/

/*
	Insight by City  
*/
-- Top 10 Best Selling and Revenue By City
select 
		row_number() over(ORDER BY sum(quantity) desc, sum(gross_sales) desc) as Ranking,
		city,
		sum(quantity) AS Total_Sell,
       sum(gross_sales) AS Total_Revenue
from sales_analysis as sa
group by city
limit 10;

-- Top 10 Lowest Selling and Revenue By City
select 
		row_number() over(ORDER BY sum(quantity) asc, sum(gross_sales) asc) as Ranking,
		city,
		sum(quantity) AS Total_Sell,
        sum(gross_sales) AS Total_Revenue
from sales_analysis as sa
group by city
limit 10;

-- City yang paling banyak melakukan ('Cancelled', 'Returned', 'Delivered')
WITH Cancelled AS (
    SELECT 
		  city AS City,
		  delivery_status AS Delivery_Status,
		  sum(quantity) AS Cancelled_Shipping,
		  ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn,
		  -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
		  concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
from sales_analysis as sa
where delivery_status = 'Cancelled'
group by City
), 
Returned AS (
	SELECT 
			  city AS City,
			  delivery_status AS Delivery_Status,
			  sum(quantity) AS Returned_Shipping,
			  ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn,
			  -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
				concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
	from sales_analysis as sa
	where delivery_status = 'Returned'
	group by City
),
Delivered AS (
		SELECT 
				  city AS City,
			      delivery_status AS Delivery_Status,
			      sum(quantity) AS Delivered_Shipping,
				  ROW_NUMBER() OVER (ORDER BY SUM(quantity) DESC) AS rn,
				  -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
					concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
		from sales_analysis as sa
		where delivery_status = 'Delivered'
		group by City
)
SELECT 
    c.City,
    c.Cancelled_Shipping,
    c.Ratio,
    r.Returned_Shipping,
    r.Ratio,
    d.Delivered_Shipping,
    d.Ratio
FROM Cancelled c
INNER JOIN Returned r ON c.rn = r.rn
INNER JOIN Delivered d ON c.rn = d.rn;

/*
			Analysis :
						Pertumbuhan bisnis digerakan oleh kota-kota satelit dan wilayah berkembang seperti Banjarmasin, Bengkulu dan Sukabumi. Namun terdapat anomaly yaitu transaksi 
                        Denpasar bali, bali menjadi kota Top 4 pendapatan terbesar sekligus wilayah dengan tingkar retur dan pembatalan yang cukup tinggi di indonesia mencapai 8%. Hal 
                        ini berimplikasi mengenai warehouse atau gudang logistik di Surabaya yang melakukan pengiriman ke Denpasar Bali, proses pengiriman yang panjang bisa menjadi salah 
                        satu faktor yang membuat paket rusak yang menyebabkan mereka membatalkan ataupun menolak paket yang diantarkan oleh kurir. Yogyakarta dan Malang menjadi wilayah 
                        dengan penjualan dan revenue terendah, mungkin dikarenakan ke 2 kota tersebut merupakan kota pelajar/mahasiswa yang didominasi oleh gen-z. Hal ini berkorelasi dengan
                        analisis sebelumnya, dimana konsumen gen-z dengan usia 17 tahun memberikan rating terendah 2.82. Artinya campaign/strategi harga yang di buat tidak cocok dengan 
                        kantong mereka, mereka memiliki ekpektasi mengenai harga yang ekonomis dan promo yang diberikan. Karena jika aspek harga dan promo yang tidak sesuai dengan 
                        ekspektasi mereka, membuat mereka enggan untuk melakukan teransaksi.       
                        
            Rekomendasi Strategi :
									-	Untuk pengiriman ke denpasar bali, bisa mengalihkan kerute menggunakan kargo penerbangan dari gudang di Jakarta, untuk memotong durasi pengiriman.
									-	Melakukan promo bundling produk untuk targen siswa atau mahasiswa. Melakukan iklan digital secara masif berdasarkan market penetration ke wilayah 
										dengan Return On Ad Spend (ROAS) yang tinggi.
*/

/*
	Analisis Berdasarkan waktu (DOD, MOM dan Jam Sibuk
*/
-- DAY-OVER-DAY (DOD)
select 
	  Day_of_Week,
      Current_DayofWeek_Sales,
      -- COALESCE(Previous_DayofWeek_Sales, 0) AS Previous_DayofWeek_Sales,
      -- Rumus DoD Growth: ((Sekarang - Lalu) / Lalu) * 100
      CASE 
        WHEN Current_DayofWeek_Sales IS NULL THEN 'New / No Data'
        ELSE CONCAT(ROUND(((Current_DayofWeek_Sales - Previous_DayofWeek_Sales) / Previous_DayofWeek_Sales) * 100, 2), '%')
      END AS DoD_Growth_Percentage
from ( 
		SELECT 
			Day_of_Week,
			SUM(quantity) AS Current_DayofWeek_Sales,
			-- Mengambil data sales dari hari sebelumnya menggunakan LAG
			 LAG(SUM(quantity)) OVER (ORDER BY FIELD(Day_of_Week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')) AS Previous_DayofWeek_Sales
		FROM sales_analysis
        GROUP BY Day_of_Week
) AS GrowthCalc;

-- MONTH-OVER-MONTH GROWTH (MOM)
WITH MonthlySales AS (
    SELECT 
        -- Mengambil tahun dan bulan dari ORDER_DATE
        DATE_FORMAT(STR_TO_DATE(transaction_date, '%d/%m/%Y'), '%Y-%m') AS YearMonth,
        SUM(quantity) AS Current_Month_Sales
    FROM sales_analysis
    GROUP BY YearMonth
    ORDER BY YearMonth
),
GrowthCalc AS (
    SELECT 
        YearMonth,
        Current_Month_Sales,
        -- Mengambil data sales dari bulan sebelumnya menggunakan LAG
        LAG(Current_Month_Sales) OVER (ORDER BY YearMonth) AS Previous_Month_Sales
    FROM MonthlySales
)
SELECT 
    YearMonth,
    Current_Month_Sales,
    COALESCE(Previous_Month_Sales, 0) AS Previous_Month_Sales,
    -- Rumus MoM Growth: ((Sekarang - Lalu) / Lalu) * 100
    CASE 
        WHEN Previous_Month_Sales IS NULL THEN 'New / No Data'
        ELSE CONCAT(ROUND(((Current_Month_Sales - Previous_Month_Sales) / Previous_Month_Sales) * 100, 2), '%')
    END AS MoM_Growth_Percentage
FROM GrowthCalc;

-- Jam Sibuk Classification
select 
	  row_number() over(ORDER BY count(transaction_id) desc, sum(quantity) desc) as Ranking,
	  CASE
			WHEN STR_TO_DATE(order_time, '%H:%i:%s') >= '04:00:00' AND STR_TO_DATE(order_time, '%H:%i:%s') < '10:00:00' THEN 'Pagi'
            WHEN STR_TO_DATE(order_time, '%H:%i:%s') >= '10:00:00' AND STR_TO_DATE(order_time, '%H:%i:%s') < '15:00:00' THEN 'Siang'
			WHEN STR_TO_DATE(order_time, '%H:%i:%s') >= '15:00:00' AND STR_TO_DATE(order_time, '%H:%i:%s') <= '18:00:00' THEN 'Sore'
            ELSE 'Malam'
      END Time_Order,
      count(transaction_id) AS Total_Transaction,
      sum(quantity) as Total_Qty_OrderCustomer,
      -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
	  concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
from sales_analysis
group by Time_Order;

-- Metrik Moving Average untuk melihat tren penjualan tanpa terganggu fluktuasi harian yang tajam
with penjualan_harian AS (
	SELECT 
			STR_TO_DATE(transaction_date, '%d/%m/%Y') AS Dates,
            SUM(gross_sales) AS Total_Revenue
	FROM 
		sales_analysis
	group by Dates
)
select
		Dates,
        Total_Revenue,
        -- 1. Menghitung 7-Day Moving Average
        avg(Total_Revenue) over(order by Dates rows between 6 preceding and current row) AS Ma_7_Days,
        -- 2. Menghitung 30-Day Moving Average
        avg(Total_Revenue) over(order by Dates rows between 29 preceding and current row) AS Ma_30_Days
from penjualan_harian
order by Dates asc;

/*
	Analysis :
				Kinerja penjualan bisnis sangat dipengaruhi oleh sifat implusif konsumen, konsumen wanita terutama generasi gen-z sangat suka berbelanja produk lipsitk (margin lipstik 76%)
                dimana 41% transaksi terjadi di malam hari melalui platform Tiktok ataupun Shopee dengan siklus mingguannya mencapai puncaknya dihari jumat. 
                Secara struktural penjualan, kestabilan penjualan tidak terjaga terbukti dengan analisis Moving Average (MA) dimana pada kuartal pertama sempat meningkat stabil akibat 
                promosi yang masif, namun mengalami penurunan secar drastis  dibulan mei 2026 yang membuat omzet turun sebesar -34.52%. Penurunan tersebut mengindikasikan bahwa pertumbuhan 
                dibulan-bulan sebelumnya hanya ditopang oleh diskon musiman bukan karena loyalitas pelanggan. Disisi lain, pembeli baru yang mendapatkan barangnya yang tidak sesuai dengan ekspektasinya,
                membuat mereka enggan untuk belanja kembali. Akibatnya puluhan pelanggan potensial langsung bergeser menjadi status At-Risk. Puncaknya terjadi pada bulan Mei 2026, 
                di mana tangki bensin promosi bisnis sudah habis, kemudian menyebabkan pertumbuhan bulanan hancur lebur di angka -34,52%.

    Rekomendasi Strategi :
							-	Memindahkan anggaran untuk program insentif khusus dibulan Januari-Maret supaya berbelanja kembali dibulan-bulan berikutnya.
							-	Saat akhir pekan, coba buat promo ataupun voucher yang bisa diclaim di toko offline guna menyeimbangkan penurunan trafik online shop.
*/