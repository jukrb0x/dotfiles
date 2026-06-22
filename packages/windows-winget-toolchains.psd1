@{
    # Optional language/toolchain managers. Required editor dependencies live in
    # packages/*-required.* and are synchronized by chezmoi apply.
    Packages = @(
        @{ Id = "Schniz.fnm" }
        @{ Id = "astral-sh.uv" }
        @{ Id = "Rustlang.Rustup" }
        @{ Id = "GoLang.Go" }
        @{ Id = "Oven-sh.Bun" }
        @{ Id = "tree-sitter.tree-sitter-cli"; Version = "0.26" }
    )
}
