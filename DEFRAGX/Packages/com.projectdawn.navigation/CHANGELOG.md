# Changelog
All notable changes to this package will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)

## [3.0.6] - 2022-1-11
- Fixed NavMesh path sometimes discarding destination

## [3.0.5] - 2022-12-26
- Fixed NavMeshAgent correctly stop if path destination can not be mapped to navmesh
- Fixed that even with OutOfNodes still returns best possible path
- Added NavMeshPath failed state and also prints the error in editor
- Added NavMeshAgent/NavMeshPath added new property MappingExtent that allows controling the maximum distance the agent will be mapped
- Added documentation links to components and package
- Changed documentation to hidden folder as now it is on webpage

## [3.0.4] - 2022-12-23
- Fixed NavMeshAgent correctly handle partial paths (Paths where destination can not be reached)
- Fixed few more cases where NavMesh update would result in "Any jobs using NavMeshQuery must be completed before we mutate the NavMesh."
- Fixed NavMeshAgent in some cases reusing path from other agent
- Changed Zerg scene camera to be centered around controllable units

## [3.0.3] - 2022-12-17
- Added to EntityBehaviour OnEnable and OnDisable
- Added error message box to AgentNavMeshAuthoring, if game objects also has NavMeshObstacle
- Added SetDestination method to AgentAuthoring
- Changed that if agent is not near any NavMesh it will throw error instead moved to the center of the world
- Fixed few cases where NavMesh update would result in "Any jobs using NavMeshQuery must be completed before we mutate the NavMesh." 

## [3.0.2] - 2022-12-15
- Fixed NavMesh at the end of destination throwing error `System.IndexOutOfRangeException: Index {0} is out of range of '{1}' Length`.
- Fixed transform sync from game object to entity not override transform in most calls.

## [3.0.1] - 2022-12-08
- Added correct documentation
- Added com.unity.modules.ui dependency as samples uses ui
- Removed second navmesh surface from zerg samples

## [3.0.0] - 2022-11-30
- Release as Agents Navigation

## [2.0.0] - 2022-06-9
- Changing velocity avoidance with new smart algorithm
- Changing package to use new Package Manager workflow
- Updating documentation to be more clear and reflect new API changes
- Adding zerg sample

## [1.0.3] - 2022-05-14
- Adding new demo scene "8 - Jobified Boids Navmesh Demo"

## [1.0.2] - 2022-03-19
- Fixing memory leaks in demo scenes

## [1.0.1] - 2022-03-08
- Updated jobs demo to not use physics and small bug fix

## [1.0.0] - 2022-02-22
- Package released