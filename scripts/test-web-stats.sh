#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v php >/dev/null 2>&1 || {
	printf 'PHP CLI is required for the web statistics checks.\n' >&2
	exit 1
}
command -v rg >/dev/null 2>&1 || {
	printf 'ripgrep is required for the web statistics security checks.\n' >&2
	exit 1
}

while IFS= read -r -d '' file; do
	php -l "$file" >/dev/null
done < <(find "$ROOT_DIR/web" "$ROOT_DIR/tests/web" -type f -name '*.php' -print0)

if rg -n -- '->(?:query|exec)\(' "$ROOT_DIR/web/src/StatsRepository.php"; then
	printf 'StatsRepository must use native prepared statements exclusively.\n' >&2
	exit 1
fi
if rg -n -i '\b(?:SHA2|CONCAT)\b' "$ROOT_DIR/web/src/StatsRepository.php"; then
	printf 'Player links must not require a computed full-table database lookup.\n' >&2
	exit 1
fi
for required_index_guard in 'SUB_PART IS NULL' "INDEX_TYPE IN ('BTREE','HASH')" IS_VISIBLE IGNORED; do
	if ! rg -Fq "$required_index_guard" "$ROOT_DIR/web/src/StatsRepository.php"; then
		printf 'StatsRepository is missing player-index guard: %s\n' "$required_index_guard" >&2
		exit 1
	fi
done
if rg -n -i '\b(?:INSERT|UPDATE|DELETE|REPLACE|ALTER|DROP|CREATE|TRUNCATE|GRANT|REVOKE)\b' \
	"$ROOT_DIR/web/src/StatsRepository.php"; then
	printf 'StatsRepository contains a write-capable SQL verb.\n' >&2
	exit 1
fi
if rg -n '\$_(?:GET|POST|REQUEST|COOKIE)' "$ROOT_DIR/web/src" "$ROOT_DIR/web/templates"; then
	printf 'Request globals must stay in the public front controller.\n' >&2
	exit 1
fi
if rg --pcre2 -n '<\?=\s+(?!e\(|pagination\(|\$content\s*\?>)' "$ROOT_DIR/web/templates"; then
	printf 'A template output expression bypasses the escaping/rendered-content allowlist.\n' >&2
	exit 1
fi
if rg --pcre2 -n '^[[:space:]]*uses:[[:space:]]+[^[:space:]]+@(?![0-9a-f]{40}(?:[[:space:]]|$))' \
	"$ROOT_DIR/.github/workflows"; then
	printf 'GitHub Actions dependencies must be pinned to immutable commit SHAs.\n' >&2
	exit 1
fi

php "$ROOT_DIR/tests/web/run.php"
printf 'PHP lint and read-only repository static checks passed.\n'
