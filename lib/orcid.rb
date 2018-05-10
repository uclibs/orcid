require 'orcid/engine' if defined?(Rails)
require 'orcid/configuration'
require 'orcid/exceptions'
require 'figaro'
require 'mappy'
require 'devise-multi_auth'
require 'virtus'
require 'omniauth-orcid'
require 'email_validator'
require 'simple_form'

# The namespace for all things related to Orcid integration
module Orcid
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end
  end

  module_function
  def configure
    yield(configuration)
  end

  def mapper
    configuration.mapper
  end

  def provider
    configuration.provider
  end

  def parent_controller
    configuration.parent_controller
  end

  def authentication_model
    configuration.authentication_model
  end

  def connect_user_and_orcid_profile(user, orcid_profile_id)
    authentication_model.create!(
      provider: 'orcid', uid: orcid_profile_id, user: user
    )
  end

  def access_token_for(orcid_profile_id, collaborators = {})
    client = collaborators.fetch(:client) { oauth_client }
    tokenizer = collaborators.fetch(:tokenizer) { authentication_model }
    tokenizer.to_access_token(
      uid: orcid_profile_id, provider: 'orcid', client: client
    )
  end

  # Returns true if the person with the given ORCID has already obtained an
  # ORCID access token by authenticating via ORCID.
  def authenticated_orcid?(orcid_profile_id)
    Orcid.access_token_for(orcid_profile_id).present?
  rescue Devise::MultiAuth::AccessTokenError
    return false
  end

  def disconnect_user_and_orcid_profile(user)
    authentication_model.where(provider: 'orcid', user: user).destroy_all
    Orcid::ProfileRequest.where(user: user).destroy_all
    true
  end

  def profile_for(user)
    auth = authentication_model.where(provider: 'orcid', user: user).first
    auth && Orcid::Profile.new(auth.uid)
  end

  def enqueue(object)
    object.run
  end

  def url_for_orcid_id(orcid_profile_id)
    File.join(provider.host_url, orcid_profile_id)
  end

  def oauth_client
    # passing the site: option as Orcid's Sandbox has an invalid certificate
    # for the api.sandbox.orcid.org
    @oauth_client ||= Devise::MultiAuth.oauth_client_for(
      'orcid', options: { site: provider.site_url }
    )
  end

  def client_credentials_token(scope, collaborators = {})
    tokenizer = collaborators.fetch(:tokenizer) { oauth_client.client_credentials }
    tokenizer.get_token(scope: scope)
  end

  # As per an isolated_namespace Rails engine.
  # But the isolated namespace creates issues.
  # @api private
  def table_name_prefix
    'orcid_'
  end

  # Because I am not using isolate_namespace for Orcid::Engine
  # I need this for the application router to find the appropriate routes.
  # @api private
  def use_relative_model_naming?
    true
  end
end
