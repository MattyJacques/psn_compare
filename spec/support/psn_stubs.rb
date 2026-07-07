module PsnStubs
  # Returns an instance_double(PSN::Client) that PSN::Client.new will return.
  # Stub resources on it per-test: allow(client).to receive_message_chain(...)
  # is banned — stub explicit doubles instead.
  def stub_psn_client(refresh_token: "rotated-token")
    client = instance_double(PSN::Client, refresh_token: refresh_token)
    allow(PSN::Client).to receive(:new).and_return(client)
    client
  end
end

RSpec.configure { |c| c.include PsnStubs }
