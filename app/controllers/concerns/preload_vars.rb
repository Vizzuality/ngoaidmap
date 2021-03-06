module PreloadVars
  extend ActiveSupport::Concern
  included do
    before_action :get_menu_items
  end
  def get_menu_items
    @organizations          = Organization.site(@site.id).active.order(:name).uniq.pluck(:id, :name)
    @donors                 = Organization.with_donations.donated_projects_site(@site.id).active_donated_projects.uniq.order(:name).uniq.pluck(:id, :name)
    @countries              = Geolocation.where(adm_level: 0).order(:name).uniq.pluck(:uid, :name)
#     @sectors                = Sector.counting_projects(status: 'active', site_id: @site.id)
    @sectors = Sector.site(@site.id).active.select('sectors.id, sectors.name, count(projects.id) as projects_count').group(:id,:name).order(:name)
    @sectors = (@sectors + (Sector.all - @sectors)).sort_by { |h| h[:name] }
    @partners               = Organization.joins(:partner_projects).merge(Project.site(@site.id).active).order(:name).uniq.pluck(:id, :name)
#     @local_partners         = Organization.local.joins(:partner_projects).merge(Project.active).order(:name).uniq.pluck(:id, :name)
#     @international_partners = Organization.international.joins(:partner_projects).merge(Project.active).order(:name).uniq.pluck(:id, :name)
  end
end
