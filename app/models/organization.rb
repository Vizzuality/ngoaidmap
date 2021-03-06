# == Schema Information
#
# Table name: organizations
#
#  id                              :integer          not null, primary key
#  name                            :string(255)
#  description                     :text
#  budget                          :float
#  website                         :string(255)
#  twitter                         :string(255)
#  facebook                        :string(255)
#  hq_address                      :string(255)
#  contact_email                   :string(255)
#  contact_phone_number            :string(255)
#  donation_address                :string(255)
#  zip_code                        :string(255)
#  city                            :string(255)
#  state                           :string(255)
#  donation_phone_number           :string(255)
#  donation_website                :string(255)
#  site_specific_information       :text
#  created_at                      :datetime
#  updated_at                      :datetime
#  logo_file_name                  :string(255)
#  logo_content_type               :string(255)
#  logo_file_size                  :integer
#  logo_updated_at                 :datetime
#  contact_name                    :string(255)
#  contact_position                :string(255)
#  contact_zip                     :string(255)
#  contact_city                    :string(255)
#  contact_state                   :string(255)
#  contact_country                 :string(255)
#  donation_country                :string(255)
#  media_contact_name              :string(255)
#  media_contact_position          :string(255)
#  media_contact_phone_number      :string(255)
#  media_contact_email             :string(255)
#  main_data_contact_name          :string(255)
#  main_data_contact_position      :string(255)
#  main_data_contact_phone_number  :string(255)
#  main_data_contact_email         :string(255)
#  main_data_contact_zip           :string(255)
#  main_data_contact_city          :string(255)
#  main_data_contact_state         :string(255)
#  main_data_contact_country       :string(255)
#  organization_id                 :string(255)
#  organization_type               :string(255)
#  organization_type_code          :integer
#  iati_organizationid             :string(255)
#  publishing_to_iati              :boolean          default(FALSE)
#  membership_status               :string(255)      default("active")
#

class Organization < ActiveRecord::Base
  has_many :resources, -> {where(element_type: 1)}, :foreign_key => :element_id, :dependent => :destroy
  has_many :media_resources, -> {where(element_type: 1).order('position ASC')}, :foreign_key => :element_id, :dependent => :destroy
  has_many :projects, foreign_key: :primary_organization_id
  has_many :awarded_projects, foreign_key: :prime_awardee_id, class_name: 'Project'
  has_many :sites, foreign_key: :project_context_organization_id
  has_many :donations, :through => :projects
  has_many :donors, through: :donations
  has_many :donations_made, foreign_key: :donor_id, dependent: :destroy, class_name: "Donation"
  has_many :offices, dependent: :destroy
  has_many :all_donated_projects, -> { uniq }, through: :donations_made, source: :project
  has_many :users
  has_many :partnerships, foreign_key: :partner_id, dependent: :destroy
  has_many :partner_projects, through: :partnerships, source: :project

  has_attached_file :logo, styles: {
                                      small: {
                                        geometry: "80x46>",
                                        format: 'jpg'
                                      },
                                      medium: {
                                        geometry: "200x150>",
                                        format: 'jpg'
                                      }
                                    },
                            url: "/system/:attachment/:id/:style.:extension"


  scope :active, -> {joins(:projects).where("projects.end_date IS NULL OR (projects.end_date > ? AND projects.start_date <= ?)", Date.today.to_s(:db), Date.today.to_s(:db))}
  scope :organizations, -> (orgs){where(organizations: {id: orgs})}
  scope :site, -> (site){joins(projects: :sites).where(sites: {id: site})}
  scope :projects, -> (projects){joins(:projects).where(projects: {id: projects})}
  scope :partners, -> (partners) { joins(projects: :partners).where(partnerships: {partner_id: partners}) }
  scope :sectors, -> (sectors){joins(:projects).joins('
    INNER JOIN projects_sectors ON (projects.id = projects_sectors.project_id)
    LEFT OUTER JOIN sectors ON (sectors.id = projects_sectors.sector_id)').where(sectors: {id: sectors})}
  scope :donors, -> (donors){joins(projects: :donations).where(donations: {donor_id: donors})}
  scope :global, -> { joins(:projects).where("projects.geographical_scope = 'global'") }
  scope :geolocation, -> (geolocation,level=0){joins(projects: :geolocations).where("g#{level}=?", geolocation).where('adm_level >= ?', level)}
  scope :countries, -> (countries){joins(projects: :geolocations).where(geolocations: {country_uid: countries})}

  scope :international, ->{ where(international: true) }
  scope :local,         ->{ where(international: [false, nil]) }
  
  scope :as_partner, -> { joins(:partnerships) }
  scope :partnership_projects, -> (projects) { joins(:partnerships => :project).where(:projects => {:id => projects }) }
  scope :active_partnership_projects, -> { joins(:partnerships => :project).merge(Project.active) }
  scope :partnership_projects_site, -> (site) { joins(:partnerships => {:project => :sites}).where(:sites => {:id => site }) }
  scope :partnership_geolocation, -> (geolocation,level=0) { joins(:partnerships => {:project => :geolocations}).where("g#{level}=? and adm_level >= ?", geolocation, level) }
  scope :partnership_global, -> { joins(partnerships: {project: :geolocations }).where("geolocations.uid = 'global'") }
  scope :partnership_countries, -> (countries) { joins(:partnerships => {:project => :geolocations }).where(:geolocations => {:country_uid => countries }) }
  scope :partnership_organizations, -> (orgs) { joins(:partnerships => :project).joins('join organizations o2 on projects.primary_organization_id = o2.id').where(:o2 => {:id => orgs}) }
  scope :partnership_partners, -> (partners) { joins(:partnerships).where(:partnerships => {:partner_id => partners}) }
  scope :partnership_donors, -> (donors) { joins(:partnerships => :project).joins('join donations on donations.project_id = projects.id join organizations as donors on donations.donor_id = donors.id').where(:donors => {:id => donors}) }
  scope :partnership_sectors, -> (sectors) { joins(:partnerships => {:project => :sectors}).where(:sectors => {:id => sectors }) }

  scope :with_donations, -> { joins(:donations_made) }
  scope :active_donated_projects, -> {joins(donations_made: :project).merge(Project.active)}
  scope :donated_projects_site, -> (site){joins(donations_made: {project: :sites}).where(sites: {id: site})}
  scope :donation_geolocation, -> (geolocation,level=0){joins(donations_made: {project: :geolocations}).where("g#{level}=?", geolocation).where('adm_level >= ?', level)}
  scope :donation_global, -> { joins(donations_made: {project: :geolocations}).where("geolocations.uid = 'global'") }
  scope :donation_projects, -> (projects){joins(donations_made: :project).where(projects: {id: projects})}
  scope :donation_countries, -> (countries){joins(donations_made: {project: :geolocations}).where(geolocations: {country_uid: countries})}
  scope :donation_organizations, -> (orgs){joins(donations_made: :project).joins('join organizations o2 on projects.primary_organization_id = o2.id').where(o2: {id: orgs})}
  scope :donation_partners, -> (partners){joins(donations_made: :project).joins('join partnerships on partnerships.project_id = projects.id join organizations as partners on partnerships.partner_id = partners.id').where(partners: {id: partners})}
  scope :donation_donors, -> (donors){joins(:donations_made).where(donations: {donor_id: donors})}
  scope :donation_sectors, -> (sectors){joins(donations_made: {project: :sectors}).where(sectors: {id: sectors})}

  scope :has_projects, -> { where('id in (select primary_organization_id from projects)') }
  
  def self.interaction_members(historic=false)
      if historic
          where("membership_status in ('Current Member', 'Former Member')")
      else
          where(membership_status: 'Current Member')
      end
  end
  
  def self.fetch_all(options={})
    level = Geolocation.find_by(uid: options[:geolocation]).adm_level if options[:geolocation]
    organizations = Organization.all
    organizations = organizations.site(options[:site])                                    if options[:site]
    organizations = organizations.active                                                  if options[:status] && options[:status] == 'active'
    organizations = organizations.geolocation(options[:geolocation], level)               if options[:geolocation] && level >= 0
    organizations = organizations.global if options[:geolocation] && level < 0
    organizations = organizations.projects(options[:projects])                            if options[:projects]
    organizations = organizations.countries(options[:countries])                          if options[:countries]
    organizations = organizations.organizations(options[:organizations])                  if options[:organizations]
    organizations = organizations.sectors(options[:sectors])                              if options[:sectors]
    organizations = organizations.donors(options[:donors])                                if options[:donors]
    organizations = organizations.partners(options[:partners]) if options[:partners]
    organizations
  end

  def self.fetch_all_donors(options={})
    level = Geolocation.find_by(uid: options[:geolocation]).adm_level if options[:geolocation]
    organizations = Organization.with_donations
    organizations = organizations.donated_projects_site(options[:site])              if options[:site]
#     organizations = organizations.active_donated_projects                            if options[:status] && options[:status] == 'active'
    organizations = organizations.active_donated_projects if options[:status] && options[:status] == 'active'
    organizations = organizations.donation_geolocation(options[:geolocation], level) if options[:geolocation] && level >= 0
    organizations = organizations.donation_global if options[:geolocation] && level < 0
    organizations = organizations.donation_projects(options[:projects])              if options[:projects]
    organizations = organizations.donation_countries(options[:countries])            if options[:countries]
    organizations = organizations.donation_organizations(options[:organizations])    if options[:organizations]
    organizations = organizations.donation_partners(options[:partners])              if options[:partners]
    organizations = organizations.donation_sectors(options[:sectors])                if options[:sectors]
    organizations = organizations.donation_donors(options[:donors])                  if options[:donors]
    organizations
  end
  
  def self.fetch_all_partners(options={})
    level = Geolocation.find_by(uid: options[:geolocation]).adm_level if options[:geolocation]
    organizations = Organization.as_partner
    organizations = organizations.partnership_projects_site(options[:site])              if options[:site]
    organizations = organizations.active_partnership_projects                            if options[:status] && options[:status] == 'active'
    organizations = organizations.partnership_geolocation(options[:geolocation], level) if options[:geolocation] && level >= 0
    organizations = organization.partnership_global if options[:geolocation] && level < 0
    organizations = organizations.partnership_projects(options[:projects])              if options[:projects]
    organizations = organizations.partnership_countries(options[:countries])            if options[:countries]
    organizations = organizations.partnership_organizations(options[:organizations])    if options[:organizations]
    organizations = organizations.partnership_partners(options[:partners])              if options[:partners]
    organizations = organizations.partnership_sectors(options[:sectors])                if options[:sectors]
    organizations = organizations.partnership_donors(options[:donors])                  if options[:donors]
    organizations
  end

  def projects_count
    self.projects.active.size
  end
  
  comma :brief do
      name 'name'
  end

  # IATI

  def iati_organization_id
    self.organization_id
  end
end
