 local variables=$(grep -E '^[A-Z_]+=' "$device_config" | cut -d= -f1)

  # Replace each variable
  for var in $variables; do
    local value="${!var}"
    # Escape special characters in value for sed
    value=$(echo "$value" | sed 's/[[\.*^$()+?{|]/\\&/g')
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
  local template_vars=$(list_template_vars "$template_file")

  # Source device config
  source "$device_config"

  for var in $template_vars; do
    if [[ -z "${!var}" ]]; then
      missing_vars+=("$var")
    fi
  done

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    print_warning "Missing variables in device config:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var"
    done
    return 1
  fi

  return 0
}

