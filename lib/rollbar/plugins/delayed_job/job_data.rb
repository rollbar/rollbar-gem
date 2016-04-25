class JobData
  attr_reader :job

  def initialize(job)
    @job = job
  end

  def to_hash
    job_data = job.as_json
    # Here job_data['handler'] is a YAML object comming
    # from the storage backend
    job_data['handler'] = job.payload_object.as_json

    job_data
  end
end
