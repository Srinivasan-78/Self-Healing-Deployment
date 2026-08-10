.PHONY: deploy chaos dashboard clean

# Good deploy — version boots healthy, previous container is discarded.
deploy:
	cd ansible && ansible-playbook -i inventory.ini deploy.yml \
		-e "target_version=$(VERSION)" -e "force_fail=false"

# Bad deploy — health gate fails, automatic rollback to last-known-good.
chaos:
	cd ansible && ansible-playbook -i inventory.ini deploy.yml \
		-e "target_version=$(VERSION)" -e "force_fail=true"

dashboard:
	docker compose up

clean:
	docker rm -f demo-service-active demo-service-previous 2>/dev/null || true
	rm -f deployment_log/deployments.json
