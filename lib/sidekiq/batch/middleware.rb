require_relative 'extension/worker'

module Sidekiq
  class Batch
    module Middleware
      class ClientMiddleware
        def call(_worker, msg, _queue, _redis_pool = nil)
          if (batch = Thread.current[:batch])
            batch.increment_job_queue(msg['jid']) if (msg[:bid] = batch.bid)
          end
          yield
        end
      end

      class ServerMiddleware
        def call(_worker, msg, _queue)
          puts 'worker'
          puts _worker
          puts msg
          puts _queue
          puts 'bid'
          puts msg['bid']
          puts "call server middleware"
          bid = msg['bid']
          if bid
            begin
              puts "inside before new bid"
              Thread.current[:batch] = Sidekiq::Batch.new(bid)
              yield
              puts "after yield"
              Thread.current[:batch] = nil
              Batch.process_successful_job(bid, msg['jid'])
            rescue
              puts "jose process failed job"
              Batch.process_failed_job(bid, msg['jid'])
              raise
            ensure
              puts "ensure stuff"
              Thread.current[:batch] = nil
            end
          else
            yield
          end
        end
      end

      def self.configure
        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::Batch::Middleware::ClientMiddleware
          end
        end
        Sidekiq.configure_server do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::Batch::Middleware::ClientMiddleware
          end
          config.server_middleware do |chain|
            chain.add Sidekiq::Batch::Middleware::ServerMiddleware
          end
        end
        Sidekiq::Worker.send(:include, Sidekiq::Batch::Extension::Worker)
      end
    end
  end
end

Sidekiq::Batch::Middleware.configure
