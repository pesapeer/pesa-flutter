FIXTURES := test/fixtures/key.pem test/fixtures/cert.pem test/fixtures/pin.txt

.PHONY: test analyze fixtures clean-fixtures

test: fixtures
	flutter test

analyze:
	flutter analyze

fixtures: $(FIXTURES)

# 820 days, not forever: on macOS Dart verifies through Apple's Security
# framework, which refuses TLS server certificates valid for more than 825
# days. Run `make clean-fixtures fixtures` when the test starts failing with
# CERTIFICATE_VERIFY_FAILED.
test/fixtures/key.pem test/fixtures/cert.pem:
	@mkdir -p test/fixtures
	openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 820 \
	  -subj '/CN=localhost' \
	  -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' -addext 'extendedKeyUsage=serverAuth' \
	  -keyout test/fixtures/key.pem -out test/fixtures/cert.pem 2>/dev/null

test/fixtures/pin.txt: test/fixtures/cert.pem
	openssl x509 -in test/fixtures/cert.pem -pubkey -noout | openssl pkey -pubin -outform der \
	  | openssl dgst -sha256 -binary | base64 > $@

clean-fixtures:
	rm -f $(FIXTURES)
