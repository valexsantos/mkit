# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Configuration Validation' do
  include Rack::Test::Methods

  def app
    MKIt::Server
  end

  describe 'Service Configuration Validation' do
    describe 'resources validation' do
      it 'validates min_replicas >= 1' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            resources:
              min_replicas: 0
        YAML
        errors = validate_service(yaml)
        assert_match(/min_replicas/, errors.join)
      end

      it 'validates max_replicas >= min_replicas' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            resources:
              min_replicas: 5
              max_replicas: 2
        YAML
        errors = validate_service(yaml)
        assert_match(/max_replicas/, errors.join)
      end

      it 'validates cpu limit format' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            resources:
              limits:
                cpu: invalid
        YAML
        errors = validate_service(yaml)
        assert_match(/cpu/, errors.join)
      end

      it 'validates memory limit format' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            resources:
              limits:
                memory: invalid
        YAML
        errors = validate_service(yaml)
        assert_match(/memory/, errors.join)
      end

      it 'accepts valid resource configuration' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            resources:
              min_replicas: 1
              max_replicas: 5
              limits:
                cpu: 500m
                memory: 256Mi
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end

      it 'validates scaling parameters' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            resources:
              scaling:
                target_cpu_percent: 150
        YAML
        errors = validate_service(yaml)
        assert_match(/target_cpu_percent/, errors.join)
      end
    end

    describe 'probe validation' do
      it 'validates probe type enum' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            liveness_probe:
              type: invalid
        YAML
        errors = validate_service(yaml)
        assert_match(/enum/, errors.join)
      end

      it 'validates probe timeout minimum' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            liveness_probe:
              type: http
              timeout_seconds: 0
        YAML
        errors = validate_service(yaml)
        assert_match(/minimum/, errors.join)
      end

      it 'accepts valid probe configuration' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            liveness_probe:
              type: http
              path: /health
              port: 8080
              initial_delay_seconds: 10
              period_seconds: 5
              timeout_seconds: 3
              failure_threshold: 3
              success_threshold: 1
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end

      it 'validates tcp probe' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            readiness_probe:
              type: tcp
              port: 5432
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end

      it 'validates exec probe' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            liveness_probe:
              type: exec
              command:
                - cat
                - /tmp/healthy
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end
    end

    describe 'service mesh validation' do
      it 'validates mtls configuration' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            service_mesh:
              mtls:
                enabled: true
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end

      it 'validates circuit breaker parameters' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            service_mesh:
              circuit_breaker:
                enabled: true
                max_failures: -1
        YAML
        errors = validate_service(yaml)
        assert_match(/max_failures/, errors.join)
      end

      it 'validates traffic splitting weights' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            service_mesh:
              traffic:
                - version: v1
                  weight: 150
        YAML
        errors = validate_service(yaml)
        assert_match(/weight/, errors.join)
      end

      it 'accepts valid service mesh configuration' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            service_mesh:
              mtls:
                enabled: true
                ca_cert: vault:/mkit/certs#CA
              circuit_breaker:
                enabled: true
                max_failures: 3
                timeout_seconds: 30
              traffic:
                - version: v1
                  weight: 90
                - version: v2
                  weight: 10
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end
    end

    describe 'volume validation' do
      it 'accepts docker volume' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            volumes:
              - docker://my-data:/data
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end

      it 'accepts bind mount' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            volumes:
              - /host/path:/container/path
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end
    end

    describe 'ingress validation' do
      it 'accepts valid ingress configuration' do
        yaml = <<~YAML
          service:
            name: test
            image: nginx
            ingress:
              frontend:
                - name: http
                  bind:
                    port: 80
                    mode: http
                  default_backend: backend
              backend:
                - name: backend
                  bind:
                    port: 8080
                    mode: http
        YAML
        errors = validate_service(yaml)
        assert_empty errors
      end
    end
  end

  private

  def validate_service(yaml)
    parsed = YAML.safe_load(yaml)
    MKIt::Validators::ServiceSchema.validate(parsed)
  end
end
