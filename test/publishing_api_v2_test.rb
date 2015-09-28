require 'test_helper'
require 'gds_api/publishing_api_v2'

describe GdsApi::PublishingApiV2 do
  include PactTest

  def content_item_for_content_id(content_id, attrs = {})
    item = {
      'content_id' => content_id,
      'base_path' => '/foo',
      "format" => "gone",
      "publishing_app" => "publisher",
      "update_type" => "major",
    }.merge(attrs)
    unless attrs.has_key?("routes")
      item["routes"] = [
        { "path" => item["base_path"], "type" => "exact" },
      ]
    end
    item
  end

  before do
    @base_api_url = Plek.current.find("publishing-api")
    @api_client = GdsApi::PublishingApiV2.new('http://localhost:3093')

    @content_id = "bed722e6-db68-43e5-9079-063f623335a7"
  end

  describe "#put_content" do
    it "responds with 200 OK if the entry is valid" do
      content_item = content_item_for_content_id(@content_id)

      publishing_api
        .given("both content stores and url-arbiter empty")
        .upon_receiving("a request to create a content item without links")
        .with(
          method: :put,
          path: "/v2/content/#{@content_id}",
          body: content_item,
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 200,
        )

      response = @api_client.put_content(@content_id, content_item)
      assert_equal 200, response.code
    end

    it "responds with 409 Conflict if the path is reserved by a different app" do
      content_item = content_item_for_content_id(@content_id, "base_path" => "/test-item", "publishing_app" => "whitehall")

      publishing_api
        .given("/test-item has been reserved in url-arbiter by the publisher application")
        .upon_receiving("a request from whitehall to create a content item at /test-item")
        .with(
          method: :put,
          path: "/v2/content/#{@content_id}",
          body: content_item,
          headers: {
            "Content-Type" => "application/json",
          }
        )
        .will_respond_with(
          status: 409,
          body: {
            "error" => {
              "code" => 422, "message" => Pact.term(generate: "Conflict", matcher:/\S+/),
              "fields" => {
                "base_path" => Pact.each_like("is already in use by the 'publisher' app", :min => 1),
              },
            },
          },
          headers: {
            "Content-Type" => "application/json; charset=utf-8"
          }
        )

      error = assert_raises GdsApi::HTTPConflict do
        @api_client.put_content(@content_id, content_item)
      end
      assert_equal "Conflict", error.error_details["error"]["message"]
    end

    it "responds with 422 Unprocessable Entity with an invalid item" do
      content_item = content_item_for_content_id(@content_id, "base_path" => "not a url path")

      publishing_api
        .given("both content stores and url-arbiter empty")
        .upon_receiving("a request to create an invalid content-item")
        .with(
          method: :put,
          path: "/v2/content/#{@content_id}",
          body: content_item,
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 422,
          body: {
            "error" => {
              "code" => 422, "message" => Pact.term(generate: "Unprocessable entity", matcher:/\S+/),
              "fields" => {
                "base_path" => Pact.each_like("is invalid", :min => 1),
              },
            },
          },
          headers: {
            "Content-Type" => "application/json; charset=utf-8"
          }
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.put_content(@content_id, content_item)
      end
      assert_equal 422, error.code
      assert_equal "Unprocessable entity", error.error_details["error"]["message"]
    end
  end

  describe "#get_content" do
    it "responds with 200 and the content item when it exists" do
      content_item = content_item_for_content_id(@content_id)
      publishing_api
        .given("a content item exists with content_id: #{@content_id}")
        .upon_receiving("a request to return the content item")
        .with(
          method: :get,
          path: "/v2/content/#{@content_id}",
        )
        .will_respond_with(
          status: 200,
          body: content_item,
          headers: {
            "Content-Type" => "application/json; charset=utf-8",
          },
        )

      response = @api_client.get_content(@content_id)
      assert_equal 200, response.code
      assert_equal content_item["format"], response["format"]
    end

    it "responds with 404 for a non-existent item" do
      publishing_api
        .given("both content stores and url-arbiter empty")
        .upon_receiving("a request for a non-existent content item")
        .with(
          method: :get,
          path: "/v2/content/#{@content_id}",
        )
        .will_respond_with(
          status: 404,
          body: {
            "error" => {"code" => 404, "message" => Pact.term(generate: "not found", matcher:/\S+/)},
          },
          headers: {
            "Content-Type" => "application/json; charset=utf-8",
          },
        )

      assert_nil @api_client.get_content(@content_id)
    end
  end

  describe "#publish" do
    it "responds with 200 if the publish command succeeds" do
      publishing_api
        .given("a draft content item exists with content_id: #{@content_id}")
        .upon_receiving("a publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
            change_note: "This is the change note."
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 200
        )

      response = @api_client.publish(@content_id,
        update_type: "major",
        change_note: "This is the change note.",
      )
      assert_equal 200, response.code
    end

    it "responds with 404 if the content item does not exist" do
      publishing_api
        .given("no content item exists with content_id: #{@content_id}")
        .upon_receiving("a publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
            change_note: "This is the change note."
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 404
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.publish(@content_id,
          update_type: "major",
          change_note: "This is the change note.",
        )
      end

      assert_equal 404, error.code
    end

    it "responds with 422 if the content item is not publishable" do
      publishing_api
        .given("an unpublishable content item exists with content_id: #{@content_id}")
        .upon_receiving("a publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
            change_note: "This is the change note."
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 422,
          body: {
            "error" => {
              "code" => 422, "message" => Pact.term(generate: "Unprocessable entity", matcher:/\S+/),
              "fields" => {
                "body" => Pact.each_like("contains invalid Govspeak links", :min => 1),
              },
            },
          }
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.publish(@content_id,
          update_type: "major",
          change_note: "This is the change note.",
        )
      end

      assert_equal 422, error.code
      assert_equal "Unprocessable entity", error.error_details["error"]["message"]
    end

    it "responds with 422 if the update information is invalid" do
      publishing_api
        .given("an draft content item exists with content_id: #{@content_id}")
        .upon_receiving("an invalid publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
            change_note: nil,
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 422,
          body: {
            "error" => {
              "code" => 422, "message" => Pact.term(generate: "Unprocessable entity", matcher:/\S+/),
              "fields" => {
                "change_note" => Pact.each_like("is required for major updates", :min => 1),
              },
            },
          }
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.publish(@content_id,
          update_type: "major",
        )
      end

      assert_equal 422, error.code
      assert_equal "Unprocessable entity", error.error_details["error"]["message"]
    end
  end
end
