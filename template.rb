# Rails application template — the other way in.
#
#   rails new my-app -m template.rb
#   rails new my-app -m https://raw.githubusercontent.com/DeliveristsIO/rails-template/main/template.rb
#
# Put the -m line in ~/.railsrc and plain `rails new my-app` applies it.
# --skip-bundle is worth adding and is not required: without it `rails new`
# bundles a Gemfile this is about to replace, and runs installers whose output
# this is about to delete. The result is the same either way.
#
# `rails new` generates a stock application; this replaces it with the
# skeleton's tracked files and renames the placeholder, so the result is the
# tree `git clone` + `bin/new-app` produces. The work happens in an
# `after_bundle` callback because that is the last thing `rails new` runs —
# apply_rails_template comes before run_bundle and before the javascript,
# hotwire, css, kamal and solid installers, every one of which would reinstall
# something the skeleton already ships.
#
#   APP_ORG=your-org        the Docker organisation config/deploy.yml pushes to
#   SKELETON_REPO=…         a clone source other than this file's own repository
#   SKELETON_BRANCH=…       a branch other than the source's default

require "fileutils"
require "shellwords"
require "tmpdir"

DEFAULT_REPO = "https://github.com/DeliveristsIO/rails-template.git"

# Run from a path, this file sits in its own working copy and that is the
# source. Run from a URL, __FILE__ is the URL and there is nothing to read.
template_home = File.expand_path("..", __FILE__) if File.file?(__FILE__)
repo = ENV["SKELETON_REPO"].presence || template_home || DEFAULT_REPO
branch = ENV["SKELETON_BRANCH"].presence
org = ENV["APP_ORG"].presence

after_bundle do
  def sh!(*command)
    say_status :run, command.join(" "), :green
    system(*command) || raise(Thor::Error, "template: `#{command.join(" ")}` failed")
  end

  say_status :skeleton, [ repo, branch ].compact.join(" "), :green

  Dir.mktmpdir do |tmp|
    clone = File.join(tmp, "skeleton")

    # No --branch unless one was asked for: the source's own default is the
    # right answer, and naming it wrongly fails the clone rather than the
    # checkout. --depth only where it means anything; git warns on a local path.
    depth = %w[ --depth 1 ] if repo.to_s.match?(%r{\A[a-z]+://|\A[^/]+@})
    sh! "git", "clone", "--quiet", *Array(depth), *(branch ? [ "--branch", branch ] : []), repo.to_s, clone

    # The generated application goes, its repository stays: `rails new` has
    # already run `git init` here and the history belongs to the new app.
    Dir.children(destination_root).each do |entry|
      FileUtils.rm_rf(File.join(destination_root, entry)) unless entry == ".git"
    end

    # Tracked files only — the same rule `bin/new-app` renames under, so a
    # .env or a .kamal/secrets in the source working copy cannot travel.
    sh! "sh", "-c", "git -C #{Shellwords.escape(clone)} archive HEAD | " \
                    "tar -x -C #{Shellwords.escape(destination_root)}"
  end

  # This file arrives with the rest of the tracked tree and has the same
  # problem bin/new-app has: it cannot survive its own success. Gone before
  # the index is built, so it is never staged and never renamed.
  FileUtils.rm_f(File.join(destination_root, "template.rb"))

  # `rails new --skip-git` leaves no repository, and bin/new-app reads the
  # index to decide what it is allowed to rewrite.
  sh! "git", "-C", destination_root, "init", "--quiet" unless File.directory?(File.join(destination_root, ".git"))
  sh! "git", "-C", destination_root, "add", "-A"

  sh! File.join(destination_root, "bin", "new-app"), app_name, *Array(org)

  # The Gemfile is not the one `rails new` bundled, whether or not it did.
  inside(destination_root) { sh! "bundle", "install", "--quiet" }
end
