import {Composition, registerRoot} from 'remotion';
import {SquatCounterFinal, SquatCounterCover} from './video';

const Root = () => (
  <>
    <Composition
      id="SquatCounterFinal"
      component={SquatCounterFinal}
      durationInFrames={1500}
      fps={30}
      width={1920}
      height={1080}
    />
    <Composition
      id="SquatCounterCover"
      component={SquatCounterCover}
      durationInFrames={1}
      fps={30}
      width={1920}
      height={1080}
    />
  </>
);

registerRoot(Root);
