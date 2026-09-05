# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Rails application template, cloned to start a product rather than run as one.
Read [README.md](README.md) first, then [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

If this repository is still called `rails-template` and `bin/new-app` still
exists, nobody has instantiated it yet — changes here land in every app that
comes after, so weigh them accordingly. If `bin/new-app` is gone, this is a
real product and the notes below are its inherited conventions.

## Ground rules

- **Placeholders are marked.** Everything that expects to be replaced says so
  in a comment beginning `TEMPLATE:`. Grep for it before starting; each one is
  a decision the product has to make, not a defect.
- **The stack is settled.** Rails edge, Hotwire, Tailwind v4, Propshaft,
  importmap, PostgreSQL, Solid Queue/Cache/Cable, Kamal, Stripe, Flipper,
  Sentry, rack-attack, `has_secure_password`. There is no `package.json` and
  adding one is a decision, not a step.
- **Match the surrounding code.** No narrated comments — a comment explains why
  something is the way it is, or it is deleted. Zeitwerk autoloading, reuse over
  invention, and the existing file's own idiom over a better one imported from
  elsewhere.
- **`bin/ci` is the definition of green**, and it runs before every push. It is
  RuboCop, i18n-tasks health, bundler-audit, importmap audit, Brakeman and the
  tests. CI runs the same command rather than re-listing the steps.
- **A ceiling is read from `Plan`, never from a constant.** Add
  `Model.ceiling_for(user)` next to the validation that enforces it, so the
  pricing table and the refusal read the same object. The free tier's numbers
  never go down.
- **Unconfigured is a supported state.** No Stripe key, no Turnstile keys, no
  Sentry DSN: the app works, quietly does less, and says so where it matters.
  Never ship a button whose route answers 404.
- **The webhook is the only thing that believes a payment.** Never unlock
  anything on the success redirect.
- **i18n EN/DE/PL from the first view.** No hardcoded strings, in views or in
  anything a visitor can be shown — including the rack-attack throttle page,
  which renders below the layout and still has to be in their language.
- **Secrets never enter the repository or the chat.** `.env`, `config/*.key`
  and `.kamal/secrets*` are gitignored; the examples next to them are the
  documentation.

## Testing

Minitest, fixtures, WebMock with `disable_net_connect!`. Every external service
is stubbed — a test that reaches a real endpoint is flaky and gets a shared
address rate-limited. When adding a guard, break it once and watch a test fail
before trusting the test.
