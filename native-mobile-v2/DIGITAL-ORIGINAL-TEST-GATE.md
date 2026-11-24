# Digital Original release gate

This development build queries the existing bb_real_invoice_digital_status RPC using the signed-in user's token and the exact invoice ID. It does not upload or register images.

Before enabling registration:
- Compare the Android renderer with official USD and KHR invoice fixtures, Khmer text, long product notes, and multiple pages. Never register a truncated first page or a development-watermarked image.
- Re-fetch the authoritative invoice and eligibility immediately before capture; require explicit confirmation that no paper invoice exists.
- Verify the backend registration RPC enforces eligibility and refuses existing images, including concurrent registrations, in both Cloud and Local Brain.
- Confirm private storage rules, unique object keys, no upsert, and recoverable handling of uncertain network responses. Do not delete registered objects on ambiguous failures.
- Verify successful registration updates Pending Scan exactly once; cancellations and failures must leave accounting records unchanged.
- Exercise cash, fully paid credit, partly paid credit, existing paper photo, existing digital original, permission denial, network interruption, and server errors on both APKs.
- Until those tests pass, leave upload and registration disabled.
