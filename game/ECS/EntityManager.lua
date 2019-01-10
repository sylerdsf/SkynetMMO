local EntityManager = BaseClass(ECS.ScriptBehaviourManager)
ECS.EntityManager = EntityManager
local table_insert = table.insert
function EntityManager:Constructor(  )
	self.entities_free_id = 0
end

function EntityManager:OnCreateManager( capacity )
	ECS.TypeManager.Initialize()
	self.Entities = ECS.EntityDataManager.New(capacity)
	self.m_SharedComponentManager = ECS.SharedComponentDataManager.New()
	self.ArchetypeManager = ECS.ArchetypeManager.New(self.m_SharedComponentManager)
	-- self.ComponentJobSafetyManager = ECS.ComponentJobSafetyManager.New()
	self.m_GroupManager = ECS.EntityGroupManager.New(self.ComponentJobSafetyManager)
	self.m_CachedComponentTypeArray = {}
	self.m_CachedComponentTypeInArchetypeArray = {}
end

local CreateEntities = function ( self, archetype, num )
    return self.Entities:CreateEntities(self.ArchetypeManager, archetype.Archetype, num)
end

function EntityManager:CreateEntityByArcheType( archetype )
    local entities = CreateEntities(self, archetype, num or 1)
	return entities and entities[1]
end

function EntityManager:CreateEntitiesByArcheType( archetype, num )
    return CreateEntities(self, archetype, num or 1)
end

function EntityManager:CreateEntityByComponents( com_types, num )
	return CreateEntities(self, self:CreateArchetype(com_types), num or 1)
end

function EntityManager:PopulatedCachedTypeInArchetypeArray( requiredComponents, count )
    self.m_CachedComponentTypeInArchetypeArray = {}
    self.m_CachedComponentTypeInArchetypeArray[1] = ECS.ComponentTypeInArchetype.Create(ECS.ComponentType.Create("ECS.Entity"))
    for i=1,count do
        ECS.SortingUtilities.InsertSorted(self.m_CachedComponentTypeInArchetypeArray, i + 1, ECS.ComponentTypeInArchetype.Create(ECS.ComponentType.Create(requiredComponents[i])))
    end
    return count + 1
end

--e.g. CreateArchetype({"ECS.Position", "OtherCompTypeName"})
function EntityManager:CreateArchetype( types )
    local cachedComponentCount = self:PopulatedCachedTypeInArchetypeArray(types, #types)

    local entityArchetype = {}
    entityArchetype.Archetype =
        self.ArchetypeManager:GetExistingArchetype(self.m_CachedComponentTypeInArchetypeArray, cachedComponentCount)
    if entityArchetype.Archetype ~= nil then
        return entityArchetype
    end
    -- self:BeforeStructuralChange()
    entityArchetype.Archetype = self.ArchetypeManager:GetOrCreateArchetype(self.m_CachedComponentTypeInArchetypeArray, cachedComponentCount, self.m_GroupManager)
    return entityArchetype
end

function EntityManager:Exists( entity )
	local index = entity.Index
    local versionMatches = self.m_Entities[index].Version == entity.Version
    local hasChunk = self.m_Entities[index].Chunk ~= nil
    return versionMatches and hasChunk;
end

function EntityManager:HasComponent( entity, com_type )
	if not self:Exists(entity) then
        return false
    end

    local archetype = self.m_Entities[entity.Index].Archetype
    return ChunkDataUtility.GetIndexInTypeArray(archetype, type) ~= -1;
end

function EntityManager:Instantiate( srcEntity )
	self:BeforeStructuralChange()
    if not Entities:Exists(srcEntity) then
        assert(false, "srcEntity is not a valid entity")
    end

    self.Entities:InstantiateEntities(self.ArchetypeManager, self.m_SharedComponentManager, self.m_GroupManager, srcEntity, outputEntities,
        count, self.m_CachedComponentTypeInArchetypeArray)
end

function EntityManager:AddComponent( entity, com_type )
	self:BeforeStructuralChange()
    self.Entities:AddComponent(entity, com_type, self.ArchetypeManager, self.m_SharedComponentManager, self.m_GroupManager,
        self.m_CachedComponentTypeInArchetypeArray)
end

function EntityManager:RemoveComponent( entity, com_type )
	self:BeforeStructuralChange()
    self.Entities:AssertEntityHasComponent(entity, type)
    self.Entities:RemoveComponent(entity, type, self.ArchetypeManager, self.m_SharedComponentManager, self.m_GroupManager,
                self.m_CachedComponentTypeInArchetypeArray)

    local archetype = self.Entities:GetArchetype(entity)
    if (archetype.SystemStateCleanupComplete) then
        self.Entities:TryRemoveEntityId(entity, 1, self.ArchetypeManager, self.m_SharedComponentManager, self.m_GroupManager, self.m_CachedComponentTypeInArchetypeArray)
    end
end

function EntityManager:AddComponentData( entity, componentTypeName, componentData )
	self:AddComponent(entity, componentTypeName)
    self:SetComponentData(entity, componentTypeName, componentData)
end

function EntityManager:SetComponentData( entity, componentTypeName, componentData )
	local typeIndex = ECS.TypeManager.GetTypeIndexByName(componentTypeName)
    -- self.Entities:AssertEntityHasComponent(entity, typeIndex)
    -- ComponentJobSafetyManager.CompleteReadAndWriteDependency(typeIndex)
    local ptr = self.Entities:GetComponentDataWithTypeRW(entity, typeIndex, self.Entities.GlobalSystemVersion)
    ECS.ChunkDataUtility.WriteComponentInChunk(ptr, componentTypeName, componentData)
    -- UnsafeUtility.CopyStructureToPtr(componentData, ptr)
end

function EntityManager:GetComponentData( entity, componentTypeName )
    local typeIndex = ECS.TypeManager.GetTypeIndexByName(componentTypeName)
    local ptr = self.Entities:GetComponentDataWithTypeRO(entity, typeIndex)
    local data = ECS.ChunkDataUtility.ReadComponentFromChunk(ptr, componentTypeName)
    return data
end

function EntityManager:GetAllEntities(  )
	
end

function EntityManager:GetComponentTypes( entity )
	-- self.Entities.AssertEntitiesExist(&entity, 1);
    local archetype = self.Entities:GetArchetype(entity)
    local components = {}
    for i=2, archetype.TypesCount do
        components[i - 1] = archetype.Types[i].ToComponentType()
    end
    return components
end

function EntityManager:GetComponentCount( entity )
	-- Entities.AssertEntitiesExist(&entity, 1);
    local archetype = self.Entities:GetArchetype(entity)
    return archetype.TypesCount - 1
end

function EntityManager:CreateComponentGroup( requiredComponents )
    return self.m_GroupManager:CreateEntityGroup(self.ArchetypeManager, self.Entities, requiredComponents)
end

function EntityManager:DestroyEntity( entity )
	
end

function EntityManager:GetArchetypeChunkComponentType( comp_type_name, isReadOnly )
    return ArchetypeChunkComponentType.New(comp_type_name, isReadOnly, self.GlobalSystemVersion)
end

local EntityArchetypeQuery = {
	Any = {}, None = {}, All = {}, 
}

local EntityArchetype = {
	
}

return EntityManager