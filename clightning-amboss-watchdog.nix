{ config, lib, pkgs, ... }:
{
  # Sends a health check ping to the Amboss API.
  # Docs: https://docs.amboss.space/api/monitoring/health-checks
  systemd.services.clightning-amboss-watchdog = let
    inherit (config.services) clightning;
    nbLib = config.nix-bitcoin.lib;
  in {
    wantedBy = [ "multi-user.target" ];
    requires = [ "clightning.service" ];
    after = [ "clightning.service" ];
    path = with pkgs; [ clightning.cli curl jq ];
    # Source: https://gist.github.com/swissrouting/111d4a615d670ddf8d11eaa8a60eacca
    script = ''
      set -euo pipefail
      URL="https://api.amboss.space/graphql"
      NOW=$(date -u +%Y-%m-%dT%H:%M:%S%z)
      SIGNATURE=$(lightning-cli signmessage "$NOW" | jq -r .zbase)
      JSON="{\"query\": \"mutation HealthCheck(\$signature: String!, \$timestamp: String!) { healthCheck(signature: \$signature, timestamp: \$timestamp) }\", \"variables\": {\"signature\": \"$SIGNATURE\", \"timestamp\": \"$NOW\"}}"
      echo "$JSON" | curl -sSf --data-binary @- -H "Content-Type: application/json" -X POST $URL
    '';
    serviceConfig = nbLib.defaultHardening // {
      DynamicUser = true;
      Group = clightning.group;
    } // nbLib.allowAllIPAddresses;
  };

  systemd.timers.clightning-amboss-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Run every x minutes
      OnUnitActiveSec = "30min";
      AccuracySec = "1min";
    };
  };
}
