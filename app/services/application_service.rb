class ApplicationService
  # Allows calling Service.call(...) instead of Service.new(...).call
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs, &block).call
  end
end
