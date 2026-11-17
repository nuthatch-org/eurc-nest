SELECT f.account, COALESCE(b.balance, 0) AS balance, f.block_number AS frozen_at FROM (
  SELECT account, kind, block_number, ROW_NUMBER() OVER (PARTITION BY account ORDER BY block_number DESC, log_index DESC) AS rn FROM (
    SELECT lower(_account) AS account, 'blacklisted' AS kind, block_number, log_index FROM "fiat_token_v2_2__blacklisted"
    UNION ALL
    SELECT lower(_account) AS account, 'unblacklisted' AS kind, block_number, log_index FROM "fiat_token_v2_2__un_blacklisted"
  )
) f LEFT JOIN (
  SELECT addr, SUM(d) AS balance FROM (
    SELECT lower("to") AS addr, CAST(value AS HUGEINT) AS d FROM "fiat_token_v2_2__transfer"
    UNION ALL SELECT lower("from") AS addr, -CAST(value AS HUGEINT) AS d FROM "fiat_token_v2_2__transfer"
  ) GROUP BY addr
) b ON b.addr = f.account WHERE f.rn = 1 AND f.kind = 'blacklisted' ORDER BY balance DESC
