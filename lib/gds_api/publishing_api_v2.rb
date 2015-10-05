require_relative 'base'

class GdsApi::PublishingApiV2 < GdsApi::Base

  def put_content(content_id, payload)
    put_json!(content_url(content_id), payload)
  end

  def get_content(content_id)
    get_json(content_url(content_id))
  end

  private

  def content_url(content_id)
    "#{endpoint}/v2/content/#{content_id}"
  end
end