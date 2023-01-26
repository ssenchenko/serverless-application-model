target:
	$(info ${HELP_MESSAGE})
	@exit 0

init:
	pip install -e '.[dev]'

test:
	AWS_DEFAULT_REGION=us-east-1 pytest --cov samtranslator --cov-report term-missing --cov-fail-under 95 -n auto tests/*

test-fast:
	pytest -x --cov samtranslator --cov-report term-missing --cov-fail-under 95 -n auto tests/*

test-cov-report:
	pytest --cov samtranslator --cov-report term-missing --cov-report html --cov-fail-under 95 tests/*

integ-test:
	pytest --no-cov integration/*

black:
	black setup.py samtranslator/* tests/* integration/* bin/*.py
	bin/json-format.py --write tests integration samtranslator/policy_templates_data
	bin/yaml-format.py --write tests
	bin/yaml-format.py --write integration --add-test-metadata

black-check:
	# Checking latest schema was generated (run `make schema` if this fails)
	mkdir -p .tmp
	python samtranslator/schema/schema.py --sam-schema .tmp/sam.schema.json --cfn-schema samtranslator/schema/cloudformation.schema.json --unified-schema .tmp/schema.json
	diff -u samtranslator/schema/sam.schema.json .tmp/sam.schema.json
	diff -u samtranslator/schema/schema.json .tmp/schema.json
	black --check setup.py samtranslator/* tests/* integration/* bin/*.py
	bin/json-format.py --check tests integration samtranslator/policy_templates_data
	bin/yaml-format.py --check tests
	bin/yaml-format.py --check integration --add-test-metadata

lint:
	# mypy performs type check
	mypy --strict samtranslator bin
	# Linter performs static analysis to catch latent bugs
	pylint --rcfile .pylintrc samtranslator
	# cfn-lint to make sure generated CloudFormation makes sense
	bin/run_cfn_lint.sh

prepare-companion-stack:
	pytest -v --no-cov integration/setup -m setup

update-schema-data:
	mkdir -p .tmp

	# Update and parse SAM docs
	rm -rf .tmp/aws-sam-developer-guide
	git clone --depth 1 https://github.com/awsdocs/aws-sam-developer-guide.git .tmp/aws-sam-developer-guide
	bin/parse_docs.py .tmp/aws-sam-developer-guide/doc_source > samtranslator/schema/docs.json

	# Update and parse CloudFormation docs
	rm -rf .tmp/aws-cloudformation-user-guide
	git clone --depth 1 git@github.com:awsdocs/aws-cloudformation-user-guide.git .tmp/aws-cloudformation-user-guide
	bin/parse_docs.py --cfn .tmp/aws-cloudformation-user-guide/doc_source > samtranslator/schema/cloudformation-docs.json

	# Update CloudFormation schema
	curl -o .tmp/cloudformation.schema.json https://raw.githubusercontent.com/awslabs/goformation/master/schema/cloudformation.schema.json

	# Add CloudFormation docs to CloudFormation schema
	python bin/add_docs_cfn_schema.py --schema .tmp/cloudformation.schema.json --docs samtranslator/schema/cloudformation-docs.json > samtranslator/schema/cloudformation.schema.json

schema:
	python samtranslator/schema/schema.py --sam-schema samtranslator/schema/sam.schema.json --cfn-schema samtranslator/schema/cloudformation.schema.json --unified-schema samtranslator/schema/schema.json

# Command to run everytime you make changes to verify everything works
dev: test

# Verifications to run before sending a pull request
pr: black-check lint init dev

clean:
	rm -rf .tmp

define HELP_MESSAGE

Usage: $ make [TARGETS]

TARGETS
	init        Initialize and install the requirements and dev-requirements for this project.
	test        Run the Unit tests.
	integ-test  Run the Integration tests.
	dev         Run all development tests after a change.
	pr          Perform all checks before submitting a Pull Request.
	prepare-companion-stack    Create or update the companion stack for running integration tests.

endef
