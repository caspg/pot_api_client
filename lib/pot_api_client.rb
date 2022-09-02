# frozen_string_literal: true

require_relative "pot_api_client/version"

require "net/http"
require "json"
require "csv"

# rubocop:disable Metrics/MethodLength, Metrics/ModuleLength
module PotApiClient
  class RateLimitError < StandardError; end

  CATEGORIES_IDS = {
    attractions: "C004", # Atrakcje turystyczne
  }.freeze

  OBJECTS_IDS_BASE_URL = "https://rit.poland.travel/api/v1/objects"
  OBJECT_BASE_URL = "https://rit.poland.travel/api/v1/objects"
  OUTPUT_JSON_PATH = "out/attractions.json"
  ITEMS_SLICE_SIZE = 20

  class << self
    def fetch_and_save_attractions
      attractions_ids = fetch_attractions_ids
      attractions_length = attractions_ids.length
      index = 0

      attractions_ids.each_slice(ITEMS_SLICE_SIZE) do |attractions_ids_slice|
        new_index = fetch_and_save_attractions_slice(attractions_ids_slice, index, attractions_length)
        index = new_index
      end

      attractions = load_attractions_from_json
      save_attractions_to_csv(attractions)
      puts "saved attractions to csv"
    end

    private

    def fetch_and_save_attractions_slice(attractions_ids_slice, current_index, total_length)
      index = current_index
      existing_attractions_json = load_attractions_from_json

      attractions_slice = attractions_ids_slice.filter_map do |attraction_id|
        index += 1

        next nil if existing_attractions_json.find { |a| a["id"] == attraction_id }

        attraction = fetch_attraction(attraction_id)
        puts "#{index} fetched. Progress: #{(index.to_f / total_length * 100).round(2)}%"
        attraction
      end

      unless attractions_slice.empty?
        new_attractions_json = existing_attractions_json.concat(attractions_slice)
        save_attractions_to_json(new_attractions_json)
        puts "saved attractions slice to json"
      end

      index
    end

    def load_attractions_from_json
      return [] unless File.file?(OUTPUT_JSON_PATH)

      file = File.read(OUTPUT_JSON_PATH)
      JSON.parse(file)
    end

    def save_attractions_to_json(attractions)
      File.open(OUTPUT_JSON_PATH, "w") do |f|
        json = JSON.pretty_generate(attractions)
        f.write(json)
      end
    end

    def save_attractions_to_csv(attractions)
      CSV.open("out/attractions.csv", "w") do |csv|
        headers = %i[
          id name description_short description lat_lng created_at updated_at
        ]

        csv << headers

        attractions.each do |attraction|
          csv << headers.map do |header|
            attraction.fetch(header.to_s)
          end
        end
      end
    end

    def fetch_attraction(id)
      url = object_url(id)
      attraction_response = get_request(url)

      {
        id: attraction_response["attributes"]["id"],
        name: attraction_response["attributes"]["A001"],
        description_short: attraction_response["attributes"]["A003"],
        description: attraction_response["attributes"]["A004"],
        lat_lng: attraction_response["attributes"]["A018"],
        created_at: attraction_response["attributes"]["created_at"],
        updated_at: attraction_response["attributes"]["updated_at"],
      }
    end

    def fetch_attractions_ids
      url = objects_ids_url(PotApiClient::CATEGORIES_IDS.fetch(:attractions))
      parsed_response = get_request(url)

      puts "parsed_response length: #{parsed_response.length}"

      parsed_response.map { |i| i["id"] }
    end

    def get_request(url)
      retries = 0

      begin
        uri = URI(url)
        response = Net::HTTP.get_response(uri)

        raise RateLimitError if response.code == "429"

        JSON.parse(response.body)
      rescue StandardError => e
        puts "#{e}; retries: #{retries}"
        raise RateLimitError unless retries < 10

        retries += 1
        sleep(60)
        retry
      end
    end

    def objects_ids_url(category_id)
      "#{OBJECTS_IDS_BASE_URL}?categories=#{category_id}"
    end

    def object_url(object_id)
      "#{OBJECT_BASE_URL}/#{object_id}"
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/ModuleLength
