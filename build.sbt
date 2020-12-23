name := "ota-lith"
organization := "com.advancedtelematic"
scalaVersion := "2.12.12"

resolvers += "ATS Releases" at "https://nexus.ota.here.com/content/repositories/releases"

resolvers += "ATS Snapshots" at "https://nexus.ota.here.com/content/repositories/snapshots"

updateOptions := updateOptions.value.withLatestSnapshots(false)

scalacOptions += "-Xlog-implicits"

libraryDependencies ++= {
  val bouncyCastleV = "1.59"
  val libatsV = "0.4.0-15-g006c435-SNAPSHOT"
  val tufV = "0.7.1-23-g3ea21d4-SNAPSHOT"

  Seq(
    "com.advancedtelematic" %% "libats" % libatsV,
    "com.advancedtelematic" %% "director-v2" % "e55efb5b82384c53f9d6063e34513d64f90139ec-SNAPSHOT",
    "com.advancedtelematic" %% "keyserver" % tufV,
    "com.advancedtelematic" %% "reposerver" % tufV,

    "org.bouncycastle" % "bcprov-jdk15on" % bouncyCastleV,
    "org.bouncycastle" % "bcpkix-jdk15on" % bouncyCastleV
  )
}

// TODO: Add to libraryDependencies when done
lazy val treehub = (ProjectRef(file("/home/simao/ats/treehub"), "root"))
lazy val device_registry = (ProjectRef(file("/home/simao/ats/ota-device-registry"), "ota-device-registry"))

dependsOn(treehub, device_registry)

enablePlugins(BuildInfoPlugin, GitVersioning, JavaAppPackaging)

buildInfoOptions += BuildInfoOption.ToMap
buildInfoOptions += BuildInfoOption.BuildTime

mainClass in Compile := Some("com.advancedtelematic.ota_lith.OtaLithBoot")

import com.typesafe.sbt.packager.docker._
import sbt.Keys._
import com.typesafe.sbt.SbtNativePackager.Docker
import DockerPlugin.autoImport._
import com.typesafe.sbt.SbtGit.git
import com.typesafe.sbt.SbtNativePackager.autoImport._
import com.typesafe.sbt.packager.linux.LinuxPlugin.autoImport._

dockerRepository in Docker := Some("advancedtelematic")

packageName in Docker := packageName.value

dockerUpdateLatest := true

dockerAliases ++= Seq(dockerAlias.value.withTag(git.gitHeadCommit.value))

defaultLinuxInstallLocation in Docker := s"/opt/${moduleName.value}"

dockerCommands := Seq(
  Cmd("FROM", "advancedtelematic/alpine-jre:adoptopenjdk-jre8u262-b10"),
  ExecCmd("RUN", "mkdir", "-p", s"/var/log/${moduleName.value}"),
  Cmd("ADD", "opt /opt"),
  Cmd("WORKDIR", s"/opt/${moduleName.value}"),
  ExecCmd("ENTRYPOINT", s"/opt/${moduleName.value}/bin/${moduleName.value}"),
  Cmd("RUN", s"chown -R daemon:daemon /opt/${moduleName.value}"),
  Cmd("RUN", s"chown -R daemon:daemon /var/log/${moduleName.value}"),
  Cmd("USER", "daemon")
)

// fork := true // TODO: Not compatible with .properties ?
