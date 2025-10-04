
  class LicensesController < ApplicationController
    # Skip CSRF for API endpoints
    skip_before_action :verify_authenticity_token,
      only: [:create_license, :start_trial, :activate_key, :validate_key, :extend_license]

    before_action :set_license, only: [:extend_license]

    # GET /api
    def index
      render json: { message: "✅ License Server is running Successfully!" }
    end

    # POST /api/createLicense
    def create_license
      assigned_to = params[:assignedTo]

      # Handle invalid date formats
      begin
        start_date = DateTime.parse(params[:startDate]).beginning_of_day
        end_date = DateTime.parse(params[:endDate]).end_of_day
      rescue ArgumentError
        return render json: { success: false, message: "Invalid date format for startDate or endDate" }
      end

      duration_days = (end_date.to_date - start_date.to_date).to_i
      name_part = (assigned_to || "USR").upcase
      duration_part = "#{duration_days}D"
      unique_part = SecureRandom.uuid.split("-").first.upcase

      auto_key = "#{name_part}-#{duration_part}-#{unique_part}"

      if LicenseKey.exists?(key: auto_key)
        return render json: { success: false, message: "Generated key already exists, please try again" }
      end

      license = LicenseKey.new(
        key: auto_key,
        assignedTo: assigned_to,
        startDate: start_date,
        endDate: end_date,
        license_type: "subscription",
        deviceId: nil,
        status: "Active"
      )

      if license.save
        render json: { success: true, message: "License created", license: license }
      else
        render json: { success: false, error: license.errors.full_messages }
      end
    end

    # POST /api/startTrial
    def start_trial
      device_id = params[:deviceId]
      return render json: { success: false, message: "Device ID required" } unless device_id

      existing = LicenseKey.find_by(deviceId: device_id, license_type: "trial")
      return render json: { success: false, message: "Trial already used on this device" } if existing

      now = DateTime.now.beginning_of_day
      trial_end = (now + 5.minutes).end_of_day
      trial_key = "TRIAL-#{SecureRandom.uuid.split("-").first.upcase}"

      if LicenseKey.exists?(key: trial_key)
        return render json: { success: false, message: "Generated trial key already exists, please try again" }
      end

      trial = LicenseKey.create(
        key: trial_key,
        license_type: "trial",
        startDate: now,
        endDate: trial_end,
        deviceId: device_id,
        status: "Active"
      )

      if trial.persisted?
        render json: { success: true, message: "Trial started", key: trial_key, expiresAt: trial_end }
      else
        render json: { success: false, error: trial.errors.full_messages }
      end
    end

    # POST /api/activateKey
    def activate_key
      license_key = params[:licenseKey]
      device_id = params[:deviceId]
      return render json: { success: false, message: "Device ID required" } unless device_id

      license = LicenseKey.find_by(key: license_key, license_type: "subscription")
      return render json: { success: false, message: "Invalid subscription key" } unless license

      now = DateTime.now
      expiry = license.endDate.end_of_day

      if now > expiry
        license.update(status: "Expired")
        return render json: { success: false, message: "Subscription expired. Please contact admin." }
      end

      if license.deviceId.present? && license.deviceId != device_id
        return render json: { success: false, message: "Key already used on another device" }
      end

      if LicenseKey.exists?(deviceId: device_id, license_type: "subscription") && license.deviceId != device_id
        return render json: { success: false, message: "Device already has an active subscription" }
      end

      license.update(deviceId: device_id) unless license.deviceId
      render json: { success: true, message: "Subscription key activated", expiresAt: expiry.iso8601 }
    end

    # POST /api/validateKey
    def validate_key
      license_key = params[:licenseKey]
      device_id = params[:deviceId]
      return render json: { valid: false, message: "Device ID required" } unless device_id

      license = LicenseKey.find_by(key: license_key)
      return render json: { valid: false, message: "Invalid key" } unless license

      if license.deviceId.present? && license.deviceId != device_id
        return render json: { valid: false, message: "Key already used on another device" }
      end

      now = DateTime.now
      expiry = license.license_type == "subscription" ? license.endDate.end_of_day : license.endDate

      if now > expiry
        license.update(status: "Expired")
        return render json: { valid: false, message: "Subscription or Trial expired. Please contact admin." }
      end

      render json: { 
        valid: true, 
        message: license.license_type == "trial" ? "Trial active" : "Subscription active",
        expiresAt: expiry.iso8601
      }
    end

    # PUT /api/extendLicense
    def extend_license
      if @license
        begin
          new_end_date = DateTime.parse(params[:newEndDate]).end_of_day
        rescue ArgumentError
          return render json: { success: false, message: "Invalid date format for newEndDate" }
        end

        @license.update(endDate: new_end_date, status: "Active")
        render json: { success: true, message: "License extended", license: @license }
      else
        render json: { success: false, message: "License not found" }
      end
    end

    private

    def set_license
      @license = LicenseKey.find_by(key: params[:key])
    end
  end
