require 'mkit/app/model/mkit_job'
require 'mkit/utils'

module MKIt
  class JobManager
    def initialize
      @workers = {}
    end

    def register_worker(worker, topics)
      topics.each { | topic |
        @workers[topic] ||= []
        MKItLogger.info("register #{worker.class} for topic #{topic}")
        @workers[topic] << worker
      }
    end

    def start
      MKItLogger.info('starting job manager')
      @thread = Thread.new do
        loop do
          job = MkitJob.take
          begin
            if job.nil?
              sleep(10)
            else
              topic = job.topic
              job.processing!
              if @workers[topic].nil?
                MKItLogger.warn("no workers found for topic '#{topic}'")
              else
                workers = @workers[topic]
                workers.each { | worker |
                  worker.do_the(job)
                }
              end 
            end
            job.done! unless job.nil?
          rescue Exception => e
            job.error! unless job.nil?
            MKItLogger.error e, e.message, e.backtrace.join("\n")
          end
        end
      end
    end

    def stop
      @thread.exit if @thread
    end
  end
end


