# Render a template file with variables from a config file
# Usage: render_template "template_file" "device_config" "output_file"
render_template() {
  local template_file=$1
  local device_config=$2
  local output_file=$3

  local temp_file
  temp_file=$(mktemp)

  cp "$template_file" "$temp_file"

  # Load config variables
  source "$device_config"
  local variables=$(grep -E '^[A-Z_]+=' "$device_config" | cut -d= -f1)

  # Replace each variable
  for var in $variables; do
    local value="${!var}"
    # Escape special characters in value for sed
    value=$(echo "$value" | sed 's/[\\.*^$()+?{}|[\]]/\\&/g')
    # Replace {{VARIABLE}} with value
    sed -i "s/{{$var}}/$value/g" "$temp_file"
  done

  # Move temp file to output
  mv "$temp_file" "$output_file"
}

# List all template variables in a file
# Usage: list_template_vars "file"
list_template_vars() {
  local file=$1
  grep -o '{{[A-Z_]*}}' "$file" 2>/dev/null | sort -u | sed 's/[{}]//g'
}

# Validate template against device config
# Usage: validate_template "template_file" "device_config"
validate_template() {
  local template_file=$1
  local device_config=$2

  local missing_vars=()
  local template_vars
  template_vars=$(list_template_vars "$template_file")

  # Source device config
  source "$device_config"

  for var in $template_vars; do
    if [[ -z "${!var}" ]]; then
      missing_vars+=("$var")
    fi
  done

  if [[ ${#missing_vars[@]} -ne 0 ]]; then
    echo "Missing variables in config: ${missing_vars[*]}"
    return 1
  fi

  return 0
}
