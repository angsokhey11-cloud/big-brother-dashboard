-- READ-ONLY illustrative calculation checks. This is NOT integration testing of
-- deployed PL/pgSQL trigger functions, and writes no production data.
-- Each "back" is unsold stock returned from Batch to Warehouse.
-- Each "reverse" restores a prior sale to the Batch and reverses historical COGS.
WITH cases(name,batch_p,batch_z,sale_p,sale_z,back_p,back_z,reverse_p,reverse_z,original_unit_cost,expect_p,expect_z,expect_cogs,should_accept) AS (
 VALUES
 ('purchased sale',20::numeric,10::numeric,3::numeric,0::numeric,0::numeric,0::numeric,0::numeric,0::numeric,0.45::numeric,17::numeric,10::numeric,1.35::numeric,true),
 ('zero-cost sale',20,10,0,2,0,0,0,0,0.45,20,8,0,true),
 ('mixed sale and back sale',20,10,3,2,1,3,0,0,0.45,16,5,1.35,true),
 ('mixed sale and reversal',20,10,3,2,0,0,1,1,0.45,18,9,0.90,true),
 ('sale back sale and reversal',20,10,3,2,1,1,1,1,0.45,17,8,0.90,true),
 ('purchased oversell',2,10,3,0,0,0,0,0,0.45,0,0,0,false),
 ('zero oversell',20,1,0,2,0,0,0,0,0.45,0,0,0,false),
 ('back exceeds available purchased',20,10,4,1,17,0,0,0,0.45,0,0,0,false),
 ('back exceeds available zero',20,10,4,1,0,10,0,0,0.45,0,0,0,false),
 ('negative source sale',20,10,-1,2,0,0,0,0,0.45,0,0,0,false),
 ('zero original purchased cost requires audit',20,10,3,0,0,0,1,0,0,0,0,0,false),
 ('reversal exceeds purchased source sold',20,10,1,2,0,0,2,0,0.45,0,0,0,false)
), evaluated AS (
 SELECT name,should_accept,
   (sale_p>=0 AND sale_z>=0 AND back_p>=0 AND back_z>=0 AND reverse_p>=0 AND reverse_z>=0
     AND sale_p<=batch_p AND sale_z<=batch_z
     AND back_p<=batch_p-sale_p AND back_z<=batch_z-sale_z
     AND reverse_p<=sale_p AND reverse_z<=sale_z
     AND (reverse_p<=0 OR original_unit_cost>0)) accepted,
   batch_p-sale_p-back_p+reverse_p actual_p,
   batch_z-sale_z-back_z+reverse_z actual_z,
   round((sale_p-reverse_p)*original_unit_cost,2) actual_cogs,
   expect_p,expect_z,expect_cogs
 FROM cases
)
SELECT name,should_accept,accepted,
 CASE WHEN should_accept THEN accepted AND abs(actual_p-expect_p)<0.000001
   AND abs(actual_z-expect_z)<0.000001 AND abs(actual_cogs-expect_cogs)<0.000001
 ELSE NOT accepted END AS test_pass,
 CASE WHEN should_accept THEN 'Batch purchased '||actual_p||', zero-cost '||actual_z||', net COGS $'||actual_cogs
 ELSE 'Rejected' END outcome
FROM evaluated ORDER BY name;
