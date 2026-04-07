{
  description = "TradeX development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        pythonPackages = pkgs.python312Packages;
        django603 = pythonPackages.buildPythonPackage rec {
          pname = "django";
          version = "6.0.3";
          format = "wheel";

          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/72/b1/23f2556967c45e34d3d3cf032eb1bd3ef925ee458667fb99052a0b3ea3a6/django-6.0.3-py3-none-any.whl";
            hash = "sha256-Lll0RBSR3bNMPxPV56n5ewe6A79wI0wKnGi3m7sjW8M=";
          };

          nativeBuildInputs = with pythonPackages; [ wheel ];
          propagatedBuildInputs = with pythonPackages; [
            asgiref
            sqlparse
          ];

          doCheck = false;
          pythonImportsCheck = [ "django" ];
        };

        djangoNinja = pythonPackages.buildPythonPackage rec {
          pname = "django-ninja";
          version = "1.6.0";
          format = "wheel";

          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/fc/ff/51e518a434f1af18932d4fe52a4c46985b7c15a75e394aeed5ed87ff6f98/django_ninja-1.6.0-py3-none-any.whl";
            hash = "sha256-RMbj9fG5Kc9R9kUARxWzYybqMv3fGpQCbEkX3o0jATU=";
          };

          nativeBuildInputs = with pythonPackages; [ wheel ];
          propagatedBuildInputs = [
            django603
            pythonPackages.pydantic
          ];

          doCheck = false;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python312
            pythonPackages.pip
            pythonPackages.virtualenv
            django603
            djangoNinja
            pythonPackages.pytest
            pythonPackages.django-cors-headers
            pythonPackages.requests
            pythonPackages.openai
            pythonPackages.chromadb
            pythonPackages.pyjwt
            nodejs_22
            pnpm
            sqlite
            openssl
            pkg-config
          ];

          shellHook = ''
            export PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            export PYTHONDONTWRITEBYTECODE=1

            # 创建虚拟环境并安装依赖
            if [ ! -d "$PROJECT_ROOT/.venv" ]; then
              echo "Creating Python venv..."
              python3 -m venv "$PROJECT_ROOT/.venv"
            fi
            source "$PROJECT_ROOT/.venv/bin/activate"
            pip install -q cos-python-sdk-v5 2>/dev/null || true

            echo "TradeX nix shell ready (project root: $PROJECT_ROOT)"
          '';
        };
      }
    );
}
