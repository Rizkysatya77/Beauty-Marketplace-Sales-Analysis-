use sales_analysis_beautycosmetic;

/* 
	RENAME COLUMN 
*/
alter table sales_analysis_beautycosmetic.product_code
rename column ï»¿product_code to product_code;

alter table sales_analysis_beautycosmetic.transactions
rename column ï»¿transaction_id to transaction_id;

/* 
	DROP COLUMNS 
*/
alter table sales_analysis
drop column return_reason;

/* 
	DROP TABEL 
*/
DROP TABLE sales_analysis;

-- Membuat tabel View karena data yang digunakan berukuran kecil hingga menengah (di bawah juta baris)
CREATE OR REPLACE VIEW `sales_analysis` AS
with Basedata as(
  select 
    ft.transaction_id ,
	ft.transaction_date DATETIME,
    DATE_FORMAT(STR_TO_DATE(transaction_date, '%d/%m/%Y'), '%W') AS Day_of_Week,
    ft.order_time,
	ft.platform ,
	ft.order_source ,
	ft.customer_id ,
	ft.customer_gender ,
	ft.customer_age ,
	ft.city  ,
	ft.membership_tier ,
	ft.quantity ,
	ft.gross_sales ,
	ft.discount_amount ,
	ft.net_sales ,
	ft.shipping_cost ,
	ft.platform_fee ,
    -- Hitung Net Profit di sini agar bisa langsung dianalisis
    (gross_sales - discount_amount - production_cost - shipping_cost - platform_fee) AS net_profit,
	ft.campaign_name ,
	ft.warehouse_origin ,
	ft.delivery_status ,
	ft.customer_rating ,
	ft.returned_flag  ,
    pc.product_name,
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
      sum(stock_qty) AS Total_StockBarang,
      sum(quantity) AS Total_Terjual,
      sum(production_cost) AS Total_Biaya_Produksi,
      sum(shipping_cost) AS Total_Biaya_Pengiriman,
      sum(platform_fee) AS Total_Platform_Fee,
	  sum(discount_amount) AS Total_Platform_Fee,
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
      sum(net_sales) AS Penjualan_Bersih,
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
				
    
    Rekomendasi Stratergi :
*/
/*
	Product Insight
*/
-- Best Product by profit_margin_pct
SELECT 
	ROW_NUMBER() OVER (ORDER BY ROUND(SUM(net_profit) / NULLIF(SUM(gross_sales), 0), 4) Desc) as Ranking,
    product_name,
    SUM(quantity) AS total_quantity,
    SUM(gross_sales) AS total_revenue,
    SUM(net_profit) AS total_profit,
    -- Margin percentage untuk melihat efisiensi
    ROUND(SUM(net_profit) / NULLIF(SUM(gross_sales), 0), 4) AS profit_margin_pct
FROM sales_analysis 
GROUP BY product_name
-- ORDER BY profit_margin_pct DESC 
;

-- Top 10 Best Selling Product, Revenue and Net Sales
select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) Desc) as Ranking,
		product_name,
        sum(quantity) AS Total_Terjual,
        sum(gross_sales) AS Total_Revenue,
        sum(net_sales) AS Penjualan_Bersih,
        round(avg(rating_average), 2) Product_Rating,
        FORMAT(sum(review_count), 0) Review_Count
from sales_analysis as sa
group by product_name;

-- Top 10 Low Selling Product, Revenue and Net Sales
select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) asc) as Ranking,
		product_name,
        sum(quantity) AS Total_Terjual,
        sum(gross_sales) AS Total_Revenue,
        sum(net_sales) AS Penjualan_Bersih,
        round(avg(rating_average), 2) Product_Rating,
        FORMAT(sum(review_count) ,0) Review_Count
from sales_analysis as sa
group by product_name
limit 10;

-- Category Selling
 select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) Desc) as Ranking,
        category AS Category,
        sum(quantity) AS Total_Terjual,
        round(avg(rating_average), 2) Product_Rating,
        FORMAT(sum(review_count) ,0) Review_Count
from sales_analysis as sa
group by category;

-- The Most of Products ('Returned', 'Cancelled', 'Delivered')
 select 
		ROW_NUMBER() OVER (ORDER BY sum(quantity) Desc) as Ranking,
        product_name AS Product_Name,
        delivery_status AS Delivery_Status, 
        sum(quantity) AS Total_Product_Cancelled
from sales_analysis as sa
where delivery_status = 'Returned'
group by product_name;

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
	Campaign & Discount Insight
*/
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
        ) AS Qt__determination -- Subquery ini hanya menghasilkan 1 baris nilai threshold (kuartil)
) AS threshold -- Subquery ini hanya menghasilkan 1 baris nilai threshold (kuartil)
GROUP BY kategori_diskon
order by total_pelanggan desc;


/*
	Customer Insight
*/
-- Ratio (%) Customer Order By gender
 select 
		customer_gender,
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
        sum(quantity) AS Total_Product_Terjual,
        concat('Rp ', FORMAT(sum(gross_sales), 2)) AS Total_Revenue,
        round(avg(customer_rating), 2) AS Customer_Rating,
        -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total quantity dari seluruh data (Male + Female). 
        concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
from sales_analysis as sa
group by membership_tier;

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
select * 
from rfm_Segmentation
-- Filtering segmen_pelanggan ('Champions','Loyal Customers','At-Risk','Hibernating')
-- where segmen_pelanggan = 'Champions'
;

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

-- Best Warehouse_origin shipping
select 
	  warehouse_origin AS Warehouse_Origin,
      sum(quantity) AS Total_Shipping,
	  concat('Rp ', FORMAT(SUM(shipping_cost), 0)) as Total_Shipping_Cost
from sales_analysis as sa
group by warehouse_origin
order by Total_Shipping DESC, Total_Shipping_Cost DESC;

-- Ratio Warehouse_origin by delivery_status
select 
	  warehouse_origin AS Warehouse_Origin,
      sum(quantity) AS Total_Shipping,
      delivery_status,
      -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
        concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 1),'%') Ratio
from sales_analysis as sa
group by warehouse_origin, delivery_status
order by Total_Shipping asc;

-- Ratio Warehouse_origin by delivery_status ('Cancelled', 'Returned', 'Delivered')
select 
	  warehouse_origin AS Warehouse_Origin,
      delivery_status,
      sum(quantity) AS Total_Shipping,
      -- Fungsi window function over(), mengabaikan pengelompokan baris dan langsung menghitung total returned_flag dari seluruh data. 
        concat(round((sum(quantity) / sum(sum(quantity)) over())*100, 0),'%') Ratio
from sales_analysis as sa
where delivery_status = 'Cancelled'
group by warehouse_origin, delivery_status
order by Total_Shipping asc;

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
select 
		row_number() over(ORDER BY sum(quantity) desc) as Ranking,
		city,
        delivery_status,
		sum(quantity) AS Total_Order
from sales_analysis as sa
where delivery_status = 'Returned'
group by city;

/*
	Campaign & Discount Insight
*/
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
        ) AS Qt__determination -- Subquery ini hanya menghasilkan 1 baris nilai threshold (kuartil)
) AS threshold -- Subquery ini hanya menghasilkan 1 baris nilai threshold (kuartil)
GROUP BY kategori_diskon
order by total_pelanggan desc;

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