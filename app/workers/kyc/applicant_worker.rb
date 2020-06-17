require 'sidekiq'
module KYC
  # TODO: Document code.
  class ApplicantWorker
    include Sidekiq::Worker

    def perform(profile_id)
      profile = Profile.find(profile_id)

      # protected_params = params.slice(:type, :first_name, :last_name, :dob, :residence_country, :email)
      params = {
        type: 'PERSON',
        first_name: profile.first_name,
        last_name: profile.last_name,
        dob: profile.dob,
        residence_country: profile.country,
        email: profile.user.email,
        phone: profile.user.phones&.last&.number
      }

      applicant = KYCAID::Applicant.create(params)

      # applicant error usually means unathorized
      # applicant errors is nil on correct request and contains a structure: (example)
      # type="validation", errors=[{"parameter"=>"residence_country", "message"=>"Country of residence is not valid"} 
      if applicant.error
        Rails.logger.error("Error in applicant creation for: #{profile.user.uid}: #{applicant.error}")
      elsif applicant.errors
        Rails.logger.info("Error in applicant creation for: #{profile.user.uid}: #{applicant.errors}")
        profile.update(applicant_id: applicant.applicant_id, state: 'rejected')
      elsif applicant.applicant_id
        profile.update(applicant_id: applicant.applicant_id, state: 'verified')
      end
    end
  end
end
