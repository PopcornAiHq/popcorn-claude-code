.PHONY: bump

bump:  ## Bump version: make bump [v=X.Y.Z] (patch if omitted)
	$(eval v := $(or $(v),$(shell python3 -c "import json; v=json.load(open('.claude-plugin/plugin.json'))['version'].split('.'); v[-1]=str(int(v[-1])+1); print('.'.join(v))")))
	@[ "$(v)" ] || { echo "Could not determine version"; exit 1; }
	@sed -i '' 's/"version": "[^"]*"/"version": "$(v)"/' .claude-plugin/plugin.json
	@sed -i '' 's/"version": "[^"]*"/"version": "$(v)"/' .claude-plugin/marketplace.json
	@git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
	@git commit -m "chore: bump version to $(v)"
	@git tag "v$(v)"
	@echo "✓ Bumped to $(v) (tagged v$(v)). Push when ready: git push && git push --tags"
