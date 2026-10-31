# Populate env vars for secrets whitelisted in MVN_CREDENTIALS.

export_secret() {
  if ! value=$(printf '%s' "${MVN_SECRETS_JSON:-}" | jq -er --arg name "$2" \
      '.[$name] // ((.MAVEN_SECRETS // "{}") | fromjson | .[$name]) // empty'); then
    echo "::error::Secret '$2' for Maven server '$1' was not passed to the workflow (add it to MAVEN_SECRETS)"
    return 1
  fi
  echo "::add-mask::$value"
  export "$2=$value"
}

[ -n "${MVN_SECRETS_JSON:-}" ] || MVN_SECRETS_JSON='{}'

# MAVEN_SECRETS is validated only when there is something to look up
if [ -n "${MVN_CREDENTIALS:-}" ] && ! printf '%s' "$MVN_SECRETS_JSON" | jq -e '(.MAVEN_SECRETS // "{}") | fromjson | type == "object"' >/dev/null 2>&1; then
  echo "::error::MAVEN_SECRETS secret is not a valid JSON object"
  unset MVN_SECRETS_JSON
  return 1
fi

# entries contain no spaces, so each line of the whitelist is one loop item (blank lines are skipped)
for entry in ${MVN_CREDENTIALS:-}; do
  server=$(echo "$entry" | cut -d: -f1)
  username=$(echo "$entry" | cut -d: -f2)
  password=$(echo "$entry" | cut -d: -f3)

  if ! export_secret "$server" "$username" || ! export_secret "$server" "$password"; then
    unset MVN_SECRETS_JSON
    return 1
  fi
done

unset -f export_secret
unset MVN_SECRETS_JSON entry server username password value
