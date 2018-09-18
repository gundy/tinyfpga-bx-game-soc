# TODO document the audio driver

# Current thoughts

- 3 channels
- each channel having:
 - square/triangle/saw/noise waveform generators
 - ring modulation / sync
- (maybe) global filter (HP/LP/BP/Notch) available to route channels through

# Programming API

The soundcard peripheral is accessible in IO mapped memory at location 0x0400_0000 onwards.

The documentation below applies to the "simple" variant of the audio module ("audio_simple").

The registers available are described below :

<table>
  <tr>
    <th rowspan="2">Address</th>
    <th rowspan="2">Voice #</th>
    <th colspan="4">Bits</th>
    <th rowspan="2">Description</th>
  </tr>
  <tr>
    <th>31:24</th>
    <th>23:16</th>
    <th>15:8</th>
    <th>7:0</th>
  </tr>
  <tr>
    <td>0400_0000</td>
    <td>1</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>F23:0: Voice frequency.<br/> Fout = (Fn * Fclk/16777216) Hz.<br/>Fclk = 1MHz</td>
  </tr>
  <tr>
    <td>0400_0004</td>
    <td>1</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;PPPP</td>
    <td>PPPP&nbsp;PPPP</td>
    <td>P11:0: Pulse width register<br/>Used when the pulse/square waveform is enabled.</td>
  </tr>
  <tr>
    <td>0400_0008</td>
    <td>1</td>
    <td>xxxx&nbsp;xxxM</td>
    <td>WWWW&nbsp;WWWW</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>
      Z = enable sync with (voice - 1)%3
      <br/>M = enable ring modulation with (voice-1)%4
      <br/>
      <br/>W7:0 = Waveform select.
      <br/>
      <br/>
      <ul>
        <li>`0000_1000` = noise</li>
        <li>`0000_0100` = square</li>
        <li>`0000_0010` = sawtooth</li>
        <li>`0000_0001` = triangle</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td>0400_000C</td>
    <td>1</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>VVVV&nbsp;VVVV</td>
    <td>
      V = volume (0..255)
    </td>
  </tr>
  <tr>
    <td>0400_0010</td>
    <td>2</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td></td>
  </tr>
  <tr>
    <td>0400_0014</td>
    <td>2</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;PPPP</td>
    <td>PPPP&nbsp;PPPP</td>
    <td></td>
  </tr>
  <tr>
    <td>0400_0018</td>
    <td>2</td>
    <td>xxxx&nbsp;xxxM</td>
    <td>WWWW&nbsp;WWWW</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>
    </td>
  </tr>
  <tr>
    <td>0400_001C</td>
    <td>2</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>VVVV&nbsp;VVVV</td>
    <td>
    </td>
  </tr>
  <!-- 3 -->
  <tr>
    <td>0400_0020</td>
    <td>3</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td></td>
  </tr>
  <tr>
    <td>0400_0024</td>
    <td>3</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;PPPP</td>
    <td>PPPP&nbsp;PPPP</td>
    <td></td>
  </tr>
  <tr>
    <td>0400_0028</td>
    <td>3</td>
    <td>xxxx&nbsp;xxxM</td>
    <td>WWWW&nbsp;WWWW</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>
    </td>
  </tr>
  <tr>
    <td>0400_002C</td>
    <td>3</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>VVVV&nbsp;VVVV</td>
    <td>
    </td>
  </tr>
  <tr>
    <td>0400_0030</td>
    <td>4</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td>FFFF&nbsp;FFFF</td>
    <td></td>
  </tr>
  <tr>
    <td>0400_0034</td>
    <td>4</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;PPPP</td>
    <td>PPPP&nbsp;PPPP</td>
    <td></td>
  </tr>
  <tr>
    <td>0400_0038</td>
    <td>4</td>
    <td>xxxx&nbsp;xxxM</td>
    <td>WWWW&nbsp;WWWW</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>
    </td>
  </tr>
  <tr>
    <td>0400_003C</td>
    <td>4</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>xxxx&nbsp;xxxx</td>
    <td>VVVV&nbsp;VVVV</td>
    <td>
    </td>
  </tr>
</table>
