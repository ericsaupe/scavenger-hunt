web: bundle exec rails server -p $PORT
worker: bundle exec sidekiq -C config/sidekiq.yml
release: bin/rails db:migrate
