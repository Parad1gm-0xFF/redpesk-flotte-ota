# Métas du dépôt : provisionnement factory, déploiement, diagnostic.
.PHONY: help check-factory provision deploy status target-check test spec lint

help:
	@echo "Cibles :"
	@echo "  provision    Crée model board + boards dans la factory (rp-cli)"
	@echo "  deploy       Release + déploiement OTA sur la flotte"
	@echo "  status       État de la flotte (boards, déploiements)"
	@echo "  target-check Diagnostic OTA sur une carte (A/B, services, device type)"
	@echo "  test         Lance les redtests en local (simulation TAP)"
	@echo "  lint         Vérifie la syntaxe des scripts shell (bash -n)"
	@echo "  spec         Valide le specfile RPM (rpmbuild --parse)"

provision:
	./scripts/factory/provision.sh

deploy:
	./scripts/factory/deploy.sh

status:
	./scripts/factory/status.sh

target-check:
	./scripts/target/check.sh

test:
	./redtests/run-redtest

lint:
	@for f in scripts/*/*.sh redtests/run-redtest; do \
		bash -n "$$f" && echo "OK: $$f" || exit 1; \
	done

spec:
	@if command -v rpmbuild >/dev/null 2>&1; then \
		rpmbuild --parse spec/redpesk-flotte-ota.spec >/dev/null && echo "specfile OK"; \
	else \
		echo "rpmbuild absent (disponible dans la factory redpesk), vérification minimale"; \
		grep -q '^Name:' spec/redpesk-flotte-ota.spec && echo "specfile OK (check minimal)"; \
	fi