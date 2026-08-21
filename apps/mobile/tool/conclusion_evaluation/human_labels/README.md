# Human-label evaluation

Human research labels are collected only through the offline research tooling in
`lib/research` and `scripts/research-dataset-cli.ts`. A case may enter the human
dataset only after the person explicitly submits that case and an
`explicit_case_submission` consent receipt is recorded. The tooling does not
read journals, archives, accounts, or production application storage, and it
does not upload data.

Use separate reviewers and one-time blind sessions. Reviewers label the case
without seeing earlier labels; results are revealed only after two distinct
reviewers submit. Research exports omit reviewer identities and session tokens.

Repository fixtures and generated examples are synthetic test cases. They are
not human labels, ground truth, field evidence, or support for precision
marketing claims. Only consented human cases that clear the machine-readable
policy in `config/research/research-policy.v1.json` can affect the claims gate.
