class HomeController < ApplicationController
  def index
    @users = User.all

    Ratchetio.report_message("Test message from controller with no data", "debug")
    Ratchetio.report_message("Test message from controller with extra data", "debug",
                             :foo => "bar", :num_users => @users.length)
  end

  def report_exception
    begin
      foo = bar
    rescue => e
      Ratchetio.report_exception(e, ratchetio_request_data, ratchetio_person_data)
    end
  end

  def cause_exception
    foo = bar
  end
end
