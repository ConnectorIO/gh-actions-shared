# Populate env vars for secrets whitelisted in MVN_CREDENTIALS.

export_secret() {
  if ! value=$(printf '%s' "$MVN_SECRETS_JSON" | jq -er --arg name "$2" '.[$name] // empty'); then
    echo "::error::Secret '$2' for Maven server '$1' is missing in MAVEN_SECRETS"
    return 1
  fi
  # GitHub masks only the whole MAVEN_SECRETS string, values taken out of it must be masked separately
  printf '%s\n' "$value" | while IFS= read -r line; do
    [ -z "$line" ] || echo "::add-mask::$line"
  done
  export "$2=$value"
}

if [ -n "${MVN_CREDENTIALS:-}" ]; then
  if [ -z "${MVN_SECRETS_JSON:-}" ]; then
    # i.e. pull requests from forks, which do not receive secrets
    echo "::warning::MAVEN_SECRETS was not passed, Maven servers from mvn_credentials have no credentials"
  elif ! printf '%s' "$MVN_SECRETS_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "::error::MAVEN_SECRETS secret is not a valid JSON object"
    unset MVN_SECRETS_JSON
    return 1
  else
    # entries contain no spaces, so each line of the whitelist is one loop item (blank lines are skipped)
    for entry in $MVN_CREDENTIALS; do
      server=$(echo "$entry" | cut -d: -f1)
      username=$(echo "$entry" | cut -d: -f2)
      password=$(echo "$entry" | cut -d: -f3)

      if ! export_secret "$server" "$username" || ! export_secret "$server" "$password"; then
        unset MVN_SECRETS_JSON
        return 1
      fi
    done
  fi
fi

unset -f export_secret
unset MVN_SECRETS_JSON entry server username password value line
