{
  description = "lanl2tz nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    }; 
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-homebrew }:
  let
    configuration = { pkgs, config, ... }: {
      nixpkgs.config.allowUnfree = true;
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [ 
	  pkgs.neovim
	  pkgs.kitty
	  pkgs.tmux
	  pkgs.obsidian
	  pkgs.zsh-powerlevel10k
	  pkgs.mkalias
        ];
  
      homebrew = {
        enable = true;
	casks = [
	  "firefox"
	  "alt-tab"
	];
	masApps = {
	};
	onActivation.cleanup = "zap";
	onActivation.autoUpdate = true;
	onActivation.upgrade = true;
      };

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];

  system.activationScripts.applications.text = let
    env = pkgs.buildEnv {
      name = "system-applications";
      paths = config.environment.systemPackages;
      pathsToLink = "/Applications";
    };
  in
    pkgs.lib.mkForce ''
      # Set up applications.
      echo "setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while read -r src; do
        app_name=$(basename "$src")
        echo "copying $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';

      system.defaults = {
        dock.autohide = true;
	dock.autohide-delay = 0.0;
	dock.autohide-time-modifier = 0.2;
	dock.expose-animation-duration = 0.2;
	dock.show-recents = false;
	dock.orientation = "right";
	dock.persistent-apps = [
	  "${pkgs.kitty}/Applications/kitty.app"
          "/Applications/Firefox.app"
	];
	NSGlobalDomain.AppleInterfaceStyle = "Dark";
	NSGlobalDomain."com.apple.swipescrolldirection" = false; 
	finder.AppleShowAllExtensions = true;
	screencapture.location = "~/Pictures/screenshots";
      };

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;
      programs.zsh.enable = true;  # default shell on catalina
      programs.zsh.promptInit = "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      users.users.lanl2tz = {
        name = "lanl2tz";
	home = "/Users/lanl2tz";
      };
      home-manager.backupFileExtension = "backup";
      nix.configureBuildUsers = true;
      nix.useDaemon = true;
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#Guans-Mac-mini
    darwinConfigurations."Guans-Mac-mini" = nix-darwin.lib.darwinSystem {
      modules = [ 
        configuration
	home-manager.darwinModules.home-manager
	{
	  home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.lanl2tz = import ./home.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
	}
	nix-homebrew.darwinModules.nix-homebrew
	{
	  nix-homebrew = {
	    enable = true;
	    # Apple silicon only
	    enableRosetta = true;
	    # User owning the Homebrew prefix
            user = "lanl2tz";

	    autoMigrate = true;
	  };
	}
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Guans-Mac-mini".pkgs;
  };
}
