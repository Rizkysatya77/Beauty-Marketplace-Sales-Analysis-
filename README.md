# Beauty-Marketplace-Sales-Analysis-

## Project Overview
This repository contains a comprehensive, A-Z end-to-end analytics deep dive into the omnichannel ecosystem of a direct-to-consumer (D2C) cosmetics brand. Operating across major digital marketplaces (Shopee, TikTok Shop), a proprietary e-commerce Website, and physical Brick-and-Mortar Retail Stores, this analysis synthesizes cross-functional datasets from the first half of 2026. The scope blends Financial Performance, Product Velocity, Logistics Risk Profiles, Geographic Penetration, and Temporal Buying Patterns to diagnose growth bottlenecks and margin leakage.

## The Core Synthesis (The Golden Thread)
"The brand’s growth engine is fundamentally driven by high-volume, late-night impulse buys on digital channels, spearheaded by young female consumers in Tier-2/Tier-3 cities purchasing high-margin (>74%) Lip Products. However, this top-line success is plagued by 'Campaign Fatigue' and severe bottom-line margin leakage. This stems from disproportionately high cancellation and return rates within complex face categories (Foundations & Cushions) dispatched from outer-island hubs (Medan & Surabaya). Online product presentation gaps and shipping friction have tanked e-commerce customer satisfaction to a critical sub-3.00 rating. This directly caused a catastrophic 0% cohort retention rate by Month 5, culminating in a severe -34.52% Month-over-Month (MoM) revenue collapse in May 2026."

##  Deep-Dive Insights by Analytics Pillars
1. The Omnichannel Gender & Satisfaction Paradox
-	High Volume, Low Satisfaction Online: Female consumers drive the highest order volume on Shopee and TikTok Shop, yet yield the lowest platform rating (2.93 - 2.94). This points to an expectation-versus-reality gap regarding product visuals, shades, and unboxing quality.
-	The Offline Validation: Conversely, female shoppers boast the highest satisfaction score (3.07 - 3.11) at physical Offline Stores. This proves product quality is structurally sound when customers can touch, feel, and swatch products in real time.
-	The Frictionless Male Shopper: Male consumers heavily dominate brick-and-mortar foot traffic but leave lower retail scores due to in-store friction (lines, stockouts). However, they express peak satisfaction (3.04) on TikTok Shop, responding well to frictionless, video-driven social commerce.

2. Product Matrix: Margin Structure vs. Operational Risk
-	The Profit Anchors (Cash Cows): The Lipstick category (Lip Mousse & Berry Lip Balm) dominates sales volume while commanding the healthiest gross profit margins at 74%–76%.
-	The Foundation Bleed: Complex complexion products (Foundations & Cushions) operate on the slimmest margins (56%–60%). Skin Veil Foundation holds the record for the highest national return volume (35 units) due to online shade-matching errors. Reverse logistics costs on these heavy items completely wipe out their thin margins.
-	The Trojan Horse Asset: Rosy Cheek Blush maintains a flawless 5.0 product rating across nearly 1 million reviews, identifying it as the ultimate value-add anchor for cross-category bundling.
  
3. Cohort Attrition & RFM Customer Segmentation Risk
-	Post-Campaign Churn (Cohort Decay): New user retention takes a nosedive from ~45% in Month 1 to 0% by Months 4 and 5. This proves that historical customer acquisition was artificially inflated by discount-driven promotions (high burn rate) rather than true brand equity.
-	Top-Heavy Revenue Vulnerability: Total revenue is heavily reliant on the entry-level Bronze membership tier (59% sales ratio), a demographic that is highly transactional and fickle.
-	At-Risk VIP Leakage: RFM modeling exposes a critical cluster of high-spending accounts (M-Value >Rp300k) stagnating in the At-Risk quadrant. These users have ghosted the platform for 13 to 37 consecutive days due to accumulated post-purchase dissatisfaction.
  
4. Supply Chain Logistics & Spatial Geography Analysis
-	High-Risk Hubs (Medan & Surabaya): While macro-level successful delivery sits at 89.3%, the Medan and Surabaya warehouses account for a staggering 56% of national returns and cancellations. Long-haul transshipment routes systematically compromise package integrity and cause severe delivery delays.
-	The Tier-2/Tier-3 Goldmine: Secondary cities like Banjarmasin, Bengkulu, and Sukabumi outpace Tier-1 metros (Jakarta) in pure revenue generation, showing highly profitable untapped digital demand.
-	The Denpasar Logistics Trap: Denpasar ranks as a Top 4 Revenue city but simultaneously registers the highest cancellation (4%) and return rates (4%) nationwide due to transit bottlenecks across the Bali straits from the Surabaya hub.
-	Stagnant Student Markets: Sales in university hubs like Yogyakarta (Ranked #1 Lowest) and Malang are practically dormant. The current pricing architecture and promo structures fail to resonate with the 17-year-old Gen-Z demographic, who also report the lowest overall satisfaction (2.82 rating).
  
5. Temporal Dynamics & Velocity Analytics
-	The Midnight Shopper (41%): Peak transaction velocity occurs during the Night window, heavily driven by late-night casual browsing and impulse buying during TikTok Shop live streams.
-	The Weekly Payday Cycle: Sales reach an absolute peak on Fridays (fueled by payday liquidity and weekend prep), followed by a sharp drop-off on Saturdays (-15.23%) as the consumer demographic shifts to real-world social activities.
-	The Financial Death Cross (May 2026): Revenue fell off a cliff in May 2026, plunging -34.52%. The 7-Day Moving Average (MA-7) crossed cleanly below the 30-Day Moving Average (MA-30), signaling a definitive trend reversal as top-of-funnel acquisition budgets dried up.

## Strategic Action Plan (Recovery Roadmap)
1.	Hardcode Regional Packaging Protocols: Mandate heavy-duty box packing and double bubble-wrapping for all complexion SKUs leaving the Medan and Surabaya hubs to survive long-haul transit to destinations like Denpasar.
2.	Optimize Website Margin Leakage: Migrate the proprietary e-commerce Website away from high-percentage payment gateways to a flat, fixed-fee structure to claw back platform fees from 5.44% down to an industry-standard 2%.
3.	Pivoting Promo Architecture: Sunset aggressive sitewide flat discounts. Reallocate margin into Value-Add Cross-Bundling (e.g., "Buy a low-margin Foundation, get a flawless 5.0-rated Rosy Cheek Blush free") to artificially boost unboxing satisfaction scores and transaction values.
4.	Deploy Late-Night Operational CS: Establish a dedicated late-night Customer Service and Live Stream moderation shift (active until 23:00 WIB) to secure payment confirmation and reduce the next-day cancellation pipeline.

# Repository  Structure
```text
/data : Anonymized raw datasets spanning omnichannel sales, logistics, and customer profiles.
/queries : SQL scripts utilizing window functions and CTEs for metrics generation (DoD, MoM, RFM, Cohorts).
/notebooks : Jupyter Notebooks documenting data sanitization, exploratory data analysis (EDA), and Moving Average time-series trend line plotting.
/dashboard : Using BI Tool Power BI or Tableu
/output : Executive summary decks and structured analytics reporting.
```
