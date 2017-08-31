require 'spec_helper'

describe Projects::UpdateService, services: true do
  let(:gitlab_shell) { Gitlab::Shell.new }
  let(:user) { create(:user) }
  let(:admin) { create(:admin) }
  let(:project) { create(:empty_project, creator_id: user.id, namespace: user.namespace) }

  describe 'update_by_user' do
    context 'when visibility_level is INTERNAL' do
      it 'updates the project to internal' do
        result = update_project(project, user, visibility_level: Gitlab::VisibilityLevel::INTERNAL)

        expect(result).to eq({ status: :success })
        expect(project).to be_internal
      end
    end

    context 'when visibility_level is PUBLIC' do
      it 'updates the project to public' do
        result = update_project(project, user, visibility_level: Gitlab::VisibilityLevel::PUBLIC)
        expect(result).to eq({ status: :success })
        expect(project).to be_public
      end
    end

    context 'when visibility levels are restricted to PUBLIC only' do
      before do
        stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC])
      end

      context 'when visibility_level is INTERNAL' do
        it 'updates the project to internal' do
          result = update_project(project, user, visibility_level: Gitlab::VisibilityLevel::INTERNAL)
          expect(result).to eq({ status: :success })
          expect(project).to be_internal
        end
      end

      context 'when visibility_level is PUBLIC' do
        it 'does not update the project to public' do
          result = update_project(project, user, visibility_level: Gitlab::VisibilityLevel::PUBLIC)

          expect(result).to eq({ status: :error, message: 'Visibility level unallowed' })
          expect(project).to be_private
        end

        context 'when updated by an admin' do
          it 'updates the project to public' do
            result = update_project(project, admin, visibility_level: Gitlab::VisibilityLevel::PUBLIC)
            expect(result).to eq({ status: :success })
            expect(project).to be_public
          end
        end
      end
    end
  end

  describe 'visibility_level' do
    let(:project) { create(:empty_project, :internal) }
    let(:forked_project) { create(:forked_project_with_submodules, :internal) }

    before do
      forked_project.build_forked_project_link(forked_to_project_id: forked_project.id, forked_from_project_id: project.id)
      forked_project.save
    end

    it 'updates forks visibility level when parent set to more restrictive' do
      opts = { visibility_level: Gitlab::VisibilityLevel::PRIVATE }

      expect(project).to be_internal
      expect(forked_project).to be_internal

      expect(update_project(project, admin, opts)).to eq({ status: :success })

      expect(project).to be_private
      expect(forked_project.reload).to be_private
    end

    it 'does not update forks visibility level when parent set to less restrictive' do
      opts = { visibility_level: Gitlab::VisibilityLevel::PUBLIC }

      expect(project).to be_internal
      expect(forked_project).to be_internal

      expect(update_project(project, admin, opts)).to eq({ status: :success })

      expect(project).to be_public
      expect(forked_project.reload).to be_internal
    end
  end

  context 'when updating a default branch' do
    let(:project) { create(:project, :repository) }

    it 'changes a default branch' do
      update_project(project, admin, default_branch: 'feature')

      expect(Project.find(project.id).default_branch).to eq 'feature'
    end
  end

  context 'when renaming a project' do
    let(:repository_storage_path) { Gitlab.config.repositories.storages['default']['path'] }

    before do
      gitlab_shell.add_repository(repository_storage_path, "#{user.namespace.full_path}/existing")
    end

    after do
      gitlab_shell.remove_repository(repository_storage_path, "#{user.namespace.full_path}/existing")
    end

    it 'does not allow renaming when new path matches existing repository on disk' do
      result = update_project(project, admin, path: 'existing')

      expect(result).to include(status: :error)
      expect(result[:message]).to include('Cannot rename project')
      expect(project.errors.messages).to have_key(:base)
      expect(project.errors.messages[:base]).to include('There is already a repository with that name on disk')
    end
  end

  context 'when passing invalid parameters' do
    it 'returns an error result when record cannot be updated' do
      result = update_project(project, admin, { name: 'foo&bar' })

      expect(result).to eq({ status: :error, message: 'Project could not be updated' })
    end
  end

  def update_project(project, user, opts)
    described_class.new(project, user, opts).execute
  end
end
