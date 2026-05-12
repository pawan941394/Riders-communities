"use client";

import { Canvas, useFrame, useLoader } from "@react-three/fiber";
import { Float } from "@react-three/drei";
import { Suspense, useMemo, useRef } from "react";
import * as THREE from "three";
import styles from "./page.module.css";

const phoneScreens = [
  "landing/1platform-overview.png",
  "/landing/create-post-screen.png",
  "/landing/ev-screen.png",
];

function PhoneDeck() {
  const group = useRef<THREE.Group>(null);
  const textures = useLoader(THREE.TextureLoader, phoneScreens);

  textures.forEach((texture) => {
    texture.colorSpace = THREE.SRGBColorSpace;
  });

  useFrame(({ clock, pointer }) => {
    if (!group.current) return;

    group.current.rotation.y =
      Math.sin(clock.elapsedTime * 0.45) * 0.16 + pointer.x * 0.12;
    group.current.rotation.x =
      Math.cos(clock.elapsedTime * 0.35) * 0.05 - pointer.y * 0.05;
    group.current.position.y = Math.sin(clock.elapsedTime * 0.8) * 0.08;
  });

  return (
    <group ref={group} rotation={[0.08, -0.18, 0]}>
      {textures.map((texture, index) => {
        const offset = index - 1;

        return (
          <Float
            key={phoneScreens[index]}
            speed={1.3 + index * 0.2}
            rotationIntensity={0.08}
            floatIntensity={0.25}
          >
            <group
              position={[offset * 1.15, Math.abs(offset) * -0.18, -Math.abs(offset) * 0.28]}
              rotation={[0.02, offset * -0.22, offset * -0.03]}
            >
              <mesh castShadow receiveShadow position={[0, 0, -0.045]}>
                <boxGeometry args={[0.86, 1.72, 0.08]} />
                <meshStandardMaterial
                  color="#071326"
                  roughness={0.24}
                  metalness={0.78}
                  emissive="#082a58"
                  emissiveIntensity={0.18}
                />
              </mesh>
              <mesh position={[0, 0, 0.004]}>
                <planeGeometry args={[0.76, 1.55]} />
                <meshStandardMaterial
                  map={texture}
                  roughness={0.12}
                  metalness={0.08}
                  emissive="#ffffff"
                  emissiveIntensity={0.04}
                />
              </mesh>
            </group>
          </Float>
        );
      })}
    </group>
  );
}

function EnergySystem() {
  const ring = useRef<THREE.Mesh>(null);
  const innerRing = useRef<THREE.Mesh>(null);
  const nodes = useMemo(
    () =>
      Array.from({ length: 18 }, (_, index) => {
        const angle = (index / 18) * Math.PI * 2;
        const radius = index % 2 === 0 ? 2.15 : 2.55;
        return {
          x: Math.cos(angle) * radius,
          y: Math.sin(angle) * radius * 0.28,
          z: -0.92 + Math.sin(angle) * 0.12,
          scale: index % 3 === 0 ? 0.055 : 0.035,
        };
      }),
    [],
  );

  useFrame(({ clock }) => {
    if (ring.current) ring.current.rotation.z = clock.elapsedTime * 0.22;
    if (innerRing.current) innerRing.current.rotation.z = -clock.elapsedTime * 0.34;
  });

  return (
    <group position={[0, -0.02, -1.1]}>
      <mesh ref={ring} rotation={[Math.PI / 2.18, 0, 0]}>
        <torusGeometry args={[2.28, 0.01, 16, 120]} />
        <meshBasicMaterial color="#20d8ff" transparent opacity={0.55} />
      </mesh>
      <mesh ref={innerRing} rotation={[Math.PI / 2.12, 0, 0]}>
        <torusGeometry args={[1.38, 0.008, 16, 100]} />
        <meshBasicMaterial color="#2f74ff" transparent opacity={0.48} />
      </mesh>
      {nodes.map((node) => (
        <mesh key={`${node.x}-${node.y}`} position={[node.x, node.y, node.z]}>
          <sphereGeometry args={[node.scale, 16, 16]} />
          <meshBasicMaterial color="#67f4ff" transparent opacity={0.82} />
        </mesh>
      ))}
    </group>
  );
}

function LightRails() {
  return (
    <group position={[0, -1.15, -0.55]}>
      {[-1.15, -0.58, 0, 0.58, 1.15].map((x, index) => (
        <mesh key={x} position={[x, index % 2 === 0 ? 0.03 : -0.04, 0]} rotation={[0, 0, 0.08]}>
          <boxGeometry args={[0.64, 0.018, 0.018]} />
          <meshBasicMaterial color={index % 2 === 0 ? "#25e1ff" : "#2f74ff"} transparent opacity={0.62} />
        </mesh>
      ))}
    </group>
  );
}

function Scene() {
  return (
    <>
      <color attach="background" args={["#eff6ff"]} />
      <ambientLight intensity={1.05} />
      <directionalLight position={[3, 4, 5]} intensity={2.5} />
      <pointLight position={[-2.7, 1.2, 2.2]} intensity={4.2} color="#1d4ed8" />
      <pointLight position={[2.5, -1.2, 1.8]} intensity={3.8} color="#16d6c6" />
      <EnergySystem />
      <LightRails />
      <PhoneDeck />
    </>
  );
}

export default function HeroScene() {
  return (
    <div className={styles.sceneShell}>
      <Canvas
        className={styles.sceneCanvas}
        camera={{ position: [0, 0.12, 4.2], fov: 38 }}
        dpr={[1, 1.75]}
        gl={{ antialias: true, alpha: false }}
        shadows
      >
        <Suspense fallback={null}>
          <Scene />
        </Suspense>
      </Canvas>
      <div className={styles.sceneHud}>
        <span>Rider Social Layer</span>
        <strong>Community · Create · EV</strong>
      </div>
    </div>
  );
}
