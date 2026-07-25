# frozen_string_literal: true

module AiAssistant
  class ProvidersController < AdminController
    before_action :find_provider, only: [:edit, :update, :destroy, :toggle]

    require_sudo_mode for: [:create, :update, :destroy]

    self.main_menu = false

    def index
      @providers = AiProvider.ordered
    end

    def new
      @provider = AiProvider.new(provider_type: 'custom')
    end

    def create
      @provider = AiProvider.new(provider_params)
      @provider.is_builtin = false

      if @provider.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to action: :index
      else
        render :new
      end
    end

    def edit; end

    def update
      if @provider.update(provider_params)
        flash[:notice] = l(:notice_successful_update)
        redirect_to action: :index
      else
        render :edit
      end
    end

    def destroy
      @provider.destroy
      flash[:notice] = l(:notice_successful_delete)
      redirect_to action: :index
    end

    def toggle
      @provider.update(is_enabled: !@provider.is_enabled)
      redirect_to action: :index
    end

    private

    def find_provider
      @provider = AiProvider.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def provider_params
      params.require(:ai_assistant_ai_provider).permit(
        :name, :slug, :api_url, :api_key,
        :default_model, :available_models, :settings, :is_enabled, :position
      )
    end
  end
end
