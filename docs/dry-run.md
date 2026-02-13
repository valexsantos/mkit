# Dry-run Mode

Preview service configurations without applying changes.

## Usage

```bash
# Preview service creation
mkit create service.yaml --dry-run

# Preview service update
mkit update service.yaml --dry-run
```

## How It Works

1. Validates YAML schema
2. Validates vault references
3. Shows preview of configuration
4. Does NOT create or modify any resources

## Example Output

```
Service configuration is valid.
Preview (dry-run):
service:
  name: my-app
  image: nginx:latest
  ...
```

## Use Cases

- Validate service definitions before deployment
- Check vault references exist
- Preview configuration changes
