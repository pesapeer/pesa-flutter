FIXTURES := test/fixtures/key.pem test/fixtures/cert.pem test/fixtures/pin.txt

.PHONY: test analyze fixtures clean-fixtures

test: fixtures
	flutter test

analyze:
	flutter analyze

fixtures: $(FIXTURES)

test/fixtures/key.pem test/fixtures/cert.pem:
	@mkdir -p test/fixtures
	openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 36500 \
	  -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
	  -keyout test/fixtures/key.pem -out test/fixtures/cert.pem 2>/dev/null

test/fixtures/pin.txt: test/fixtures/cert.pem
	openssl x509 -in test/fixtures/cert.pem -pubkey -noout | openssl pkey -pubin -outform der \
	  | openssl dgst -sha256 -binary | base64 > $@

clean-fixtures:
	rm -f $(FIXTURES)
