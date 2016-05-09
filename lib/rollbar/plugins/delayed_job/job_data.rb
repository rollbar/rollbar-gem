class JobData
  attr_reader :job

  def initialize(job)
    @job = job
  end

  def to_hash
    job_data = job.as_json
    handler_parent = job_data['job'] ? job_data['job'] : job_data
    handler_parent['handler'] = handler_data

    job_data
  end

  private

  def handler_data
    object = job.payload_object.object

    {
      :method_name => job.payload_object.method_name,
      :args => job.payload_object.args,
      :object => object.is_a?(Class) ? object.name : object.to_s
    }
  rescue
    {}
  end
end
