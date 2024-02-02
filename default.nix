{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.glitchtip;
  env = {
    GLITCHTIP_DOMAIN = "https://${cfg.hostname}";
    DEFAULT_FROM_EMAIL = cfg.defaultFromEmail;
    ENABLE_USER_REGISTRATION = if cfg.enableUserRegistration then "TRUE" else "FALSE";
    DATABASE_URL = "postgresql:///glitchtip?host=/run/postgresql&user=glitchtip&password=glitchtip";
    REDIS_URL = "redis://127.0.0.1:6379/1";
  } // cfg.extraEnv;
in
{
  options.services.glitchtip = {
    enable = mkEnableOption "glitchtip";

    hostname = mkOption {
      description = ''
        The virtual hostname on which nginx will host the application.
      '';
      example = "glitchtip.example.com";
      type = types.str;
    };

    environmentFile = mkOption {
      description = ''
        Path to a file containing secret environment variables that should be
        passed to glitchtip. Currently this has to contain the SECRET_KEY,
        and EMAIL_URL.
      '';
      example = "/run/secrets/glitchtip";
      type = types.str;
    };

    defaultFromEmail = mkOption {
      description = ''
        The email from which mails will be sent.
      '';
      example = "info@example.com";
      type = types.str;
    };

    extraEnv = mkOption {
      description = ''
        Extra env variables. This will be passed on to both the web and worker process.
      '';
      default = { };
      example = {
        MAILGUN_API_URL = "https://api.eu.mailgun.net/v3";
      };
    };

    enableUserRegistration = mkOption {
      description = ''
        When True, any user will be able to register. When False, user self-signup is disabled after the first user is registered.
        Subsequent users must be created by a superuser on the backend and organization invitations may only be sent to existing users.
      '';
      default = false;
      example = true;
    };

    nginx = mkOption {
      default = {
        forceSSL = true;
        enableACME = true;
      };
      example = { basicAuthFile = ./path/to/basic/auth/file; };
      description = ''
        With this option, you can customize an nginx virtualHost which already
        has sensible defaults for glitchtip. Set this to {} to just enable the
        virtualHost if you don't need any customization. If this is set to
        null (the default), no nginx virtualHost will be configured.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ ];

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_14;
      authentication = "local glitchtip all trust";
      ensureDatabases = [ "glitchtip" ];
      ensureUsers = [{
        name = "glitchtip";
        ensurePermissions = { "DATABASE glitchtip" = "ALL PRIVILEGES"; };
      }];
    };

    services.redis = {
      servers = {
        "" = {
          enable = true;
        };
      };
    };

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers = {
      glitchtip = {
        image = "glitchtip/glitchtip";
        autoStart = true;
        ports = [ "8080:8080/tcp" ];
        # entrypoint = "./bin/run-migrate-and-runserver.sh";
        environmentFiles = [
          cfg.environmentFile
        ];
        extraOptions = [
          "--mount=type=bind,source=/run/postgresql,destination=/run/postgresql"
          "--network=host"
        ];
        environment = env;
      };
      glitchtip-worker = {
        image = "glitchtip/glitchtip";
        autoStart = true;
        entrypoint = "./bin/run-celery-with-beat.sh";
        environmentFiles = [
          cfg.environmentFile
        ];
        extraOptions = [
          "--mount=type=bind,source=/run/postgresql,destination=/run/postgresql"
          "--network=host"
        ];
        environment = env;
      };
    };

    users.users.glitchtip = {
      group = "glitchtip";
      isSystemUser = true;
    };
    users.groups.glitchtip = { };

    services.nginx.virtualHosts = mkIf (cfg.nginx != null) {
      "${cfg.hostname}" = mkMerge [
        cfg.nginx
        {
          locations = {
            "/" = {
              extraConfig = ''
                proxy_pass http://127.0.0.1:8080;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
        }
      ];
    };
  };
}
