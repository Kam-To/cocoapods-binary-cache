module PodPrebuild
  def self.state
    @state ||= State.new
  end

  class State
    def initialize
      @store = {
        :cache_validation => CacheValidationResult.new,
        :artifacts => {}
      }
    end

    def update(data)
      @store.merge!(data)
    end

    def cache_validation
      @store[:cache_validation]
    end

    def artifacts
      @store[:artifacts] || {}
    end

    def artifact_for(name)
      artifacts[name]
    end
  end
end
