require 'mkit/status'
module MKIt
  class ASaga

    # Must define topics method on subclass 
    def initialize
      System[:job_manager].register_worker(self, self.topics)
    end 

  end
end
