require_relative 'base'
require_relative 'panopticon/registerer'

class GdsApi::Panopticon < GdsApi::Base
  def all
    url = base_url + '.json'
    json = get_json url
    to_ostruct json
  end

  def artefact_for_slug(slug, opts = {})
    return nil if slug.nil? or slug == ''
    get_json(url_for_slug(slug))
  end

  def create_artefact(artefact)
    post_json(base_url + ".json", artefact)
  end

  def update_artefact(id_or_slug, artefact)
    put_json("#{base_url}/#{id_or_slug}.json", artefact)
  end

private
  def base_url
    "#{endpoint}/artefacts"
  end
end
