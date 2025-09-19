Rails.application.routes.draw do
  root "licenses#index"

  post "/createLicense", to: "licenses#create_license"
  post "/startTrial", to: "licenses#start_trial"
  post "/activateKey", to: "licenses#activate_key"
  post "/validateKey", to: "licenses#validate_key"
  put  "/extendLicense", to: "licenses#extend_license"
end
