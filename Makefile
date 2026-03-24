.PHONY: bump

bump:
	@test -n "$(v)" || (echo "Usage: make bump v=X.Y.Z" && exit 1)
	@sed -i '' 's/"version": "[^"]*"/"version": "$(v)"/' .claude-plugin/plugin.json
	@sed -i '' 's/"version": "[^"]*"/"version": "$(v)"/' .claude-plugin/marketplace.json
	@git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
	@git commit -m "chore: bump version to $(v)"
	@echo "✓ Bumped to $(v). Push when ready: git push"
