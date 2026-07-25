# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

require 'fog/aws'

module Redmine
  module Storage
    class Cloud
      attr_reader :config

      def initialize(config = nil)
        @config = config || load_config
        validate_config!
        @connection = nil
        @directory = nil
      end

      # The fog-aws connection, lazily initialized
      def connection
        @connection ||= Fog::Storage.new(connection_params)
      end

      # The S3 bucket (fog directory object)
      def directory
        @directory ||= begin
          dir = connection.directories.get(@config[:bucket])
          dir || connection.directories.create(key: @config[:bucket])
        rescue Excon::Error::Forbidden
          # Bucket may not exist or access denied — try to create it
          connection.directories.create(key: @config[:bucket])
        end
      end

      # Upload a file object to S3
      def upload(key, body, content_type: nil)
        body = body.read if body.respond_to?(:read)
        directory.files.create(
          key: key,
          body: body,
          content_type: content_type || 'application/octet-stream',
          public: false
        )
      end

      # Upload an IO stream to S3 (used in create_diskfile pattern)
      # Yields an IO-like object that the caller writes to,
      # then uploads the result.
      def upload_stream(key, content_type: nil)
        buffer = StringIO.new
        yield buffer if block_given?
        buffer.rewind
        upload(key, buffer, content_type: content_type)
      end

      # Get file body from S3
      def get(key)
        file = directory.files.get(key)
        file&.body
      end

      # Download to a local file path
      def download_to(key, local_path)
        file = directory.files.get(key)
        return false unless file

        File.open(local_path, 'wb') { |f| f.write(file.body) }
        true
      end

      # Check if file exists
      def exists?(key)
        return false if key.blank?

        directory.files.head(key).present?
      rescue Excon::Error::NotFound
        false
      end

      # Delete a file from S3
      def delete(key)
        file = directory.files.get(key)
        file&.destroy
      end

      # Copy a file within the same bucket
      def copy(source_key, dest_key)
        directory.files.get(source_key)&.copy(directory.key, dest_key)
      end

      # Move (copy + delete)
      def move(source_key, dest_key)
        copy(source_key, dest_key)
        delete(source_key)
      end

      private

      def load_config
        {
          bucket: ENV['ATTACHMENTS_S3_BUCKET'].presence ||
                  Redmine::Configuration['attachments_storage_bucket'] ||
                  'redmine',
          provider: 'AWS',
          region: ENV['ATTACHMENTS_S3_REGION'].presence ||
                  Redmine::Configuration['self_attachment_s3_region'] ||
                  'us-east-1',
          aws_access_key_id: ENV['ATTACHMENTS_S3_ACCESS_KEY_ID'].presence ||
                             Redmine::Configuration['self_attachment_s3_access_key_id'],
          aws_secret_access_key: ENV['ATTACHMENTS_S3_SECRET_ACCESS_KEY'].presence ||
                                 Redmine::Configuration['self_attachment_s3_secret_access_key'],
          endpoint: ENV['ATTACHMENTS_S3_ENDPOINT'].presence ||
                    Redmine::Configuration['self_attachment_s3_endpoint'],
          path_style: true,
          connection_options: {}
        }
      end

      def connection_params
        params = {
          provider: @config[:provider],
          region: @config[:region],
          aws_access_key_id: @config[:aws_access_key_id],
          aws_secret_access_key: @config[:aws_secret_access_key],
          path_style: @config[:path_style]
        }
        params[:endpoint] = @config[:endpoint] if @config[:endpoint].present?

        # MinIO requires path-style addressing
        if @config[:endpoint].present?
          params[:path_style] = true
          # Don't use virtual hosted-style buckets with custom endpoints
          params[:aws_session_token] = nil
        end

        params
      end

      def validate_config!
        missing = []
        missing << 'aws_access_key_id / ATTACHMENTS_S3_ACCESS_KEY_ID' if @config[:aws_access_key_id].nil? || @config[:aws_access_key_id].to_s.strip.empty?
        missing << 'aws_secret_access_key / ATTACHMENTS_S3_SECRET_ACCESS_KEY' if @config[:aws_secret_access_key].nil? || @config[:aws_secret_access_key].to_s.strip.empty?

        if missing.any?
          raise ArgumentError, "Cloud storage config missing: #{missing.join(', ')}"
        end
      end
    end
  end
end
